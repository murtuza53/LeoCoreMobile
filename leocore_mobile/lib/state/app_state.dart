import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File, Platform;
import 'dart:math' show Random;

import 'package:dio/dio.dart' show Dio, Options, ResponseType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/biometrics.dart';
import '../api/repositories.dart';
import '../api/secure_store.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import '../data/mock_data.dart';
import '../l10n/ar.dart';
import '../models/documents.dart';
import '../models/permissions.dart';
import '../models/models.dart';
import '../models/reports.dart';
import '../utils/money.dart';
import 'paged_list.dart';

enum Screen {
  login,
  home,
  products,
  product,
  scan,
  customers,
  customer,
  suppliers,
  statementPicker,
  statement,
  count,
  low,
  invoice,
  quotation,
  quotations,
  receipt,
  managerReports,
  labels,
  documents,
  reports,
  settings,
  more,
}

enum Role { manager, salesRep, storekeeper }

extension RoleLabel on Role {
  String get label => switch (this) {
        Role.manager => 'Manager',
        Role.salesRep => 'Sales Rep',
        Role.storekeeper => 'Storekeeper',
      };
}

enum StockLevel { inStock, low, out }

StockLevel stockLevelOf(int stock) => stock <= 0
    ? StockLevel.out
    : stock <= 25
        ? StockLevel.low
        : StockLevel.inStock;

/// Single source of truth. Runs in one of two modes:
///  • **demo** (default / "Face ID") — the offline sample dataset;
///  • **live** — signed into a real LeoCore server, data from `/api/mobile/v1`.
///
/// Screens read the same getters in both modes, so the UI is mode-agnostic.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  /// Coming back to the app renews the session, so the sign-in lasts as long
  /// as the app keeps being opened (each renewal restarts the server's
  /// refresh-token lifetime). Throttled so quick app switches don't hit the
  /// server every time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || demoMode || sessionLocked) return;
    _refreshPermissions();
    final last = _lastRenewal;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) return;
    _renewSession();
  }

  DateTime? _lastRenewal;

  /// Re-reads the menu so a change on the server's permission page reaches
  /// the phone when the app comes back to the foreground (at most once a
  /// minute). A failed read keeps the rights already known.
  DateTime? _permsAt;
  Future<void> _refreshPermissions() async {
    final at = _permsAt;
    if (at != null && DateTime.now().difference(at) < const Duration(minutes: 1)) return;
    _permsAt = DateTime.now();
    try {
      await _setPermissions(await _repo.permissions());
      if (!_screenAllowed(screen)) screen = Screen.home;
      notifyListeners();
    } catch (_) {/* offline — keep what we had */}
  }

  Future<void> _setPermissions(MobilePermissions p) async {
    _perms = p;
    _permsAt = DateTime.now();
    try {
      await _store.setPermissions(jsonEncode(p.toJson()));
    } catch (_) {/* the cache is a convenience */}
  }

  /// Reads the user's rights first — every other load depends on them. A role
  /// without Mobile Access (403) gets an empty set; offline uses the copy saved
  /// on this phone at the last sign-in. Leaves [_perms] unknown only when
  /// neither is available.
  Future<void> _loadPermissions() async {
    try {
      await _setPermissions(await _repo.permissions());
      return;
    } on ApiException catch (e) {
      if (e.isForbidden) {
        await _setPermissions(MobilePermissions.fromMenu(const {'permissions': {}}));
        return;
      }
    } catch (_) {/* offline — try the saved copy */}
    try {
      final raw = await _store.permissions;
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) _perms = MobilePermissions.fromMenu(j);
      }
    } catch (_) {/* corrupt copy — ignore */}
  }

  /// Rotates the tokens. Returns false only when the server rejected the
  /// session (the user is sent to login); offline keeps the saved session.
  Future<bool> _renewSession() async {
    final outcome = await api.renewSession();
    if (outcome == RefreshOutcome.ok) _lastRenewal = DateTime.now();
    if (outcome == RefreshOutcome.revoked) return false; // already signed out
    if (outcome != RefreshOutcome.rejected) return true;
    if (screen != Screen.login) {
      await _store.clearTokens();
      _onSessionExpired();
    }
    return false;
  }

  /// Global navigator key so state-level flows (e.g. the "no PDF viewer" prompt)
  /// can present a dialog without a widget context. Wired into [MaterialApp].
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ── networking ─────────────────────────────────────────────────────
  final SecureStore _store = SecureStore();
  final Biometrics _bio = Biometrics();
  late final ApiClient api = ApiClient(_store)
    ..onSessionExpired = _onSessionExpired
    ..onAccessRevoked = _onAccessRevoked;
  late final AuthApi _auth = AuthApi(api, _store);
  late final LeoRepository _repo = LeoRepository(api);

  /// Device has usable fingerprint/biometric hardware + enrolment.
  bool biometricAvailable = false;

  /// A saved session exists but is locked behind fingerprint unlock.
  bool sessionLocked = false;

  bool demoMode = true; // becomes false after a successful live login
  bool loggingIn = false;
  String? loginErrMsg;
  bool dataLoading = false;
  String? dataError;
  ApiUser? me;
  MobilePermissions _perms = MobilePermissions.unknown;
  List<String> _liveCategories = [];
  Map<String, int> _categoryIds = {};

  /// Filter chips: live categories in live mode, the demo set otherwise.
  List<String> get categoryChips =>
      demoMode ? MockData.categories : ['All', ..._liveCategories];

  // Live datasets (null → fall back to the demo dataset).
  List<Product>? _products;
  List<Customer>? _customers;
  KpiData? kpis;
  StatementResult? _statement;
  bool statementLoading = false;
  List<LedgerEntry>? _ledger;
  bool ledgerLoading = false;
  Product? _productDetail;
  List<StockRowData>? _lowStock;
  List<StockRowData>? _deadStock;
  bool stockAlertsLoading = false;
  List<Customer>? _suppliers;
  bool suppliersLoading = false;
  ReportData? salesRep;
  ReportData? purchaseRep;
  bool reportsLoading = false;
  /// Real last-7-days sales trend for the Home chart (live mode).
  List<({String label, double total})>? homeTrend;
  List<({int id, String code, String name})> _warehouses = [];
  int warehouseId = 0;

  // ── appearance & role ──────────────────────────────────────────────
  bool isDark = false;
  Role role = Role.manager;
  String lang = 'en';

  /// Context-free translator for strings built inside the state layer (toasts,
  /// derived labels). Widgets use `context.tr(...)`; both read [kArabic].
  String t(String en) => lang == 'ar' ? (kArabic[en] ?? en) : en;

  // ── navigation ─────────────────────────────────────────────────────
  Screen screen = Screen.login;

  // ── login ──────────────────────────────────────────────────────────
  String loginUser = '';
  String loginPass = '';
  bool loginErr = false;
  bool keep = true;
  String serverUrl = 'https://leocoredemo.seksolution.com';
  // Servers with a past successful login (most-recent-first) — dropdown source.
  List<String> serverHistory = [];

  // ── products ───────────────────────────────────────────────────────
  String query = '';
  String cat = 'All';
  bool refreshing = false;

  // ── product detail ─────────────────────────────────────────────────
  int pid = 1;
  String prodTab = 'info';
  bool editSheet = false;
  String editBarcode = '';
  String editPrice = '';

  // ── sheets & warehouse ─────────────────────────────────────────────
  bool whSheet = false;
  bool filterSheet = false;
  String wh = 'Main WH · Tubli';

  // ── customers ──────────────────────────────────────────────────────
  int cid = 1;

  // ── scan ───────────────────────────────────────────────────────────
  bool scanFound = false;

  // ── stock count (demo-only; no server endpoint yet) ────────────────
  bool countStarted = false;
  bool countSubmitted = false;
  /// Counted quantity per item — only items the user actually counted. An
  /// item that isn't here is left alone on submit (never zeroed).
  Map<int, int> counts = {};
  final Map<int, CountSheetRow> _countRows = {};
  int _countWarehouse = 0;
  String countQuery = '';
  bool submittingCount = false;
  String? countDocNumber;
  int countAdjusted = 0;
  String? _countIdemKey;

  // ── low / dead stock ───────────────────────────────────────────────
  String stockTab = 'low';

  // ── cash sale (draft) ──────────────────────────────────────────────
  // A cash sale starts empty and is saved to the ERP as a DRAFT — payment is
  // taken later in the full app, so the mobile app collects no tenders.
  List<CartLine> cart = [];
  bool savingDraft = false;

  // ── quotation ──────────────────────────────────────────────────────
  List<CartLine> quoteLines = [];
  int quoteCustomerId = 0;
  String quoteCustomerQuery = '';
  bool savingQuote = false;
  bool quotePdfBusy = false;

  /// The document returned by the server after a successful save.
  SalesDocResult? savedDoc;

  /// Which document the scanner / "add item" actions feed into.
  String activeDoc = 'cash'; // cash | quotation

  // Idempotency keys are held per in-progress document so a retry after a
  // timeout replays the original request instead of duplicating it.
  String? _draftIdemKey;
  String? _quoteIdemKey;

  static String _newIdemKey() {
    final r = Random();
    return List<int>.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ── reports ────────────────────────────────────────────────────────
  String reportRange = '7d';

  // ── settings ───────────────────────────────────────────────────────
  bool biometrics = true;
  bool offline = false;

  // ── toast ──────────────────────────────────────────────────────────
  String? toast;
  Timer? _toastTimer;

  // ══════════════════════════════════════════════════════════════════
  //  Data source (live-or-demo)
  // ══════════════════════════════════════════════════════════════════
  List<Product> get products => demoMode ? MockData.products : (_products ?? const []);
  List<Customer> get customers => demoMode ? MockData.customers : (_customers ?? const []);

  Product productById(int id) => products.firstWhere(
        (p) => p.id == id,
        orElse: () => products.isNotEmpty ? products.first : MockData.products.first,
      );

  Product get product => (!demoMode && _productDetail != null && _productDetail!.id == pid)
      ? _productDetail!
      : productById(pid);
  Customer get customer => customers.firstWhere(
        (c) => c.id == cid,
        orElse: () => customers.isNotEmpty ? customers.first : MockData.customers.first,
      );

  /// Customer 360 outstanding + aging come from the statement (the list
  /// endpoint has no balances), falling back to the customer record in demo.
  double get customerOutstanding => (!demoMode && _statement != null) ? _statement!.closing : customer.out;
  List<double> get customerAging => (!demoMode && _statement != null) ? _statement!.aging : customer.aging;

  // ── Signed-in identity (live user, or the demo persona) ────────────
  String get userName => demoMode ? 'Yousif Mahmood' : (me?.name.isNotEmpty == true ? me!.name : 'User');
  String get userFirstName => userName.split(' ').first;
  String get userInitials {
    final parts = userName.split(' ').where((w) => w.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get userHandle => demoMode
      ? 'yousif.m · LeoCore Trading WLL'
      : [
          if (me?.email?.isNotEmpty == true) me!.email! else loginUser,
          Uri.tryParse(ApiClient.normalizeBase(serverUrl))?.host ?? serverUrl,
        ].where((s) => s.isNotEmpty).join(' · ');

  String get userRoleLabel => demoMode
      ? role.label
      : (me != null && me!.roles.isNotEmpty ? me!.roles.first : 'User');

  bool get canWrite => demoMode ? true : (me?.canWrite ?? false);

  // ── Statement as-on date ───────────────────────────────────────────
  DateTime? statementAsOn; // null = today / latest
  String get statementAsOnLabel => DateFormat('dd MMM yyyy').format(statementAsOn ?? DateTime.now());

  // ══════════════════════════════════════════════════════════════════
  //  Server-paged lists (infinite scroll + server search)
  // ══════════════════════════════════════════════════════════════════
  late final PagedList<Product> productList = PagedList<Product>((page, size, q) async {
    if (demoMode) {
      final ql = q.toLowerCase();
      return PageResult(
        MockData.products.where((p) {
          final catOk = cat == 'All' || p.cat == cat;
          final qOk = ql.isEmpty ||
              p.name.toLowerCase().contains(ql) ||
              p.code.toLowerCase().contains(ql) ||
              p.barcode.contains(ql);
          return catOk && qOk;
        }).toList(),
        false,
      );
    }
    final r = await _repo.productsPage(
      search: q,
      categoryId: cat == 'All' ? null : _categoryIds[cat],
      page: page,
      pageSize: size,
    );
    _products = _merge(_products, r.items, (p) => p.id);
    return r;
  }, onChanged: notifyListeners, idOf: (p) => p.id);

  final PartyFilter customerFilter = PartyFilter();
  final PartyFilter supplierFilter = PartyFilter();
  final PartyFilter statementFilter = PartyFilter();

  late final PagedList<Customer> customerList = _customerPages(customerFilter);
  late final PagedList<Customer> statementList = _customerPages(statementFilter);

  PagedList<Customer> _customerPages(PartyFilter f) => PagedList<Customer>((page, size, q) async {
        if (demoMode) return PageResult(_demoParties(MockData.customers, q, f), false);
        final r = await _repo.partiesPage('customers',
            search: q, hideZero: f.hideZero, byBalance: f.byBalance, page: page, pageSize: size);
        _customers = _merge(_customers, r.items, (c) => c.id);
        return r;
      }, onChanged: notifyListeners, idOf: (c) => c.id);

  late final PagedList<Customer> supplierList = PagedList<Customer>((page, size, q) async {
    if (demoMode) return const PageResult(<Customer>[], false);
    final f = supplierFilter;
    final r = await _repo.partiesPage('suppliers',
        search: q, hideZero: f.hideZero, byBalance: f.byBalance, page: page, pageSize: size);
    _suppliers = _merge(_suppliers, r.items, (c) => c.id);
    return r;
  }, onChanged: notifyListeners, idOf: (c) => c.id);

  late final PagedList<QuotationSummary> quoteList = PagedList<QuotationSummary>((page, size, q) async {
    if (demoMode) throw ApiException('DEMO', t('Saved quotations are available after live sign-in'));
    return _repo.quotations(search: q, page: page, pageSize: size);
  }, onChanged: notifyListeners, pageSize: 30, idOf: (x) => x.id);

  late final PagedList<CountSheetRow> countList = PagedList<CountSheetRow>((page, size, q) async {
    final PageResult<CountSheetRow> r;
    if (demoMode) {
      final ql = q.toLowerCase();
      r = PageResult(
        [
          for (final e in MockData.expected.entries)
            if (ql.isEmpty ||
                MockData.byId(e.key).name.toLowerCase().contains(ql) ||
                MockData.byId(e.key).code.toLowerCase().contains(ql))
              CountSheetRow(
                itemId: e.key,
                code: MockData.byId(e.key).code,
                name: MockData.byId(e.key).name,
                barcode: MockData.byId(e.key).barcode,
                expected: e.value,
              ),
        ],
        false,
      );
    } else {
      r = await _repo.stockCountSheet(warehouseId: _countWarehouse, search: q, page: page, pageSize: size);
    }
    for (final row in r.items) {
      _countRows[row.itemId] = row;
    }
    return r;
  }, onChanged: notifyListeners, idOf: (x) => x.itemId);

  /// Adds freshly loaded rows to the cache that [productById], [customer] and
  /// [supplier] read from (an updated row replaces the cached one).
  static List<T> _merge<T>(List<T>? cache, List<T> fresh, Object Function(T) id) {
    final out = [...?cache];
    final index = {for (var i = 0; i < out.length; i++) id(out[i]): i};
    for (final x in fresh) {
      final at = index[id(x)];
      if (at == null) {
        index[id(x)] = out.length;
        out.add(x);
      } else {
        out[at] = x;
      }
    }
    return out;
  }

  static List<Customer> _demoParties(List<Customer> all, String q, PartyFilter f) {
    final ql = q.toLowerCase();
    final rows = all
        .where((c) =>
            (!f.hideZero || c.out != 0) &&
            (ql.isEmpty ||
                c.name.toLowerCase().contains(ql) ||
                c.area.toLowerCase().contains(ql) ||
                c.phone.toLowerCase().contains(ql)))
        .toList();
    if (f.byBalance) rows.sort((a, b) => b.out.compareTo(a.out));
    return rows;
  }

  void _resetLists() {
    productList.reset();
    customerList.reset();
    statementList.reset();
    supplierList.reset();
    quoteList.reset();
    countList.reset();
    query = '';
    cat = 'All';
    customerQuery = '';
    supplierQuery = '';
    statementQuery = '';
    _suppliers = null;
  }

  void toggleHideZero(PartyFilter f, PagedList<Customer> list) {
    f.hideZero = !f.hideZero;
    list.refresh();
  }

  void toggleByBalance(PartyFilter f, PagedList<Customer> list) {
    f.byBalance = !f.byBalance;
    list.refresh();
  }


  List<Product> get lowRows => products.where((p) => p.stock > kUnknownStock && p.stock <= 25).toList();

  // ── customers search ───────────────────────────────────────────────
  String customerQuery = '';

  void setCustomerQuery(String v) {
    customerQuery = v;
    customerList.setSearch(v);
  }

  /// Suppliers (live); empty until loaded.
  List<Customer> get suppliers => _suppliers ?? const [];

  /// Warehouses for the company/warehouse switcher.
  List<({int id, String code, String name})> get warehouseOptions => _warehouses;

  /// Company/workspace label for the header + switcher.
  String get companyLabel {
    if (demoMode) return 'LeoCore Trading WLL';
    final host = Uri.tryParse(ApiClient.normalizeBase(serverUrl))?.host ?? serverUrl;
    final first = host.split('.').first;
    return first.isEmpty ? host : '${first[0].toUpperCase()}${first.substring(1)}';
  }

  String get companySub {
    if (demoMode) return 'CR 84921-1 · Manama';
    return Uri.tryParse(ApiClient.normalizeBase(serverUrl))?.host ?? serverUrl;
  }

  /// Live low-stock rows (from `/inventory/low-stock`); null until loaded.
  List<StockRowData>? get lowStockRows => _lowStock;
  List<StockRowData>? get deadStockRows => _deadStock;

  /// Total AR shown on the Customers header — the dashboard KPI is authoritative
  /// in live mode; otherwise sum the loaded customers.
  double get arTotal => (!demoMode && kpis?.outstandingAr != null)
      ? kpis!.outstandingAr!
      : customers.fold(0.0, (a, c) => a + c.out);

  // statement / ledger — live when available, else demo sample
  List<StmtRow> get stmtRows => demoMode ? MockData.stmt : (_statement?.rows ?? const []);
  double get statementClosing => (!demoMode && _statement != null) ? _statement!.closing : customer.out;
  List<LedgerEntry> get ledgerRows => demoMode ? MockData.ledger : (_ledger ?? const []);

  // ── KPI display values (live → formatted, else demo defaults) ──────
  String get kpiSales => kpis?.salesToday != null ? Money.fmt(kpis!.salesToday!) : (demoMode ? '1,842.500' : '—');
  String get kpiCollections => kpis?.collections != null ? Money.fmt(kpis!.collections!) : (demoMode ? '940.250' : '—');
  String get kpiOutstanding => kpis?.outstandingAr != null ? Money.fmt(kpis!.outstandingAr!) : (demoMode ? '13,276.500' : '—');
  String get kpiLowStock => kpis?.lowStock != null ? '${kpis!.lowStock}' : (demoMode ? '7' : '—');

  // KPI sub-chips. In live mode only show figures the API actually returns —
  // an empty string hides the chip rather than showing invented numbers.
  String get kpiSalesChip => demoMode
      ? '▲ 12.4% vs yesterday'
      : (kpis?.salesThisMonth != null ? 'MTD ${Money.fmt(kpis!.salesThisMonth!)}' : '');
  String get kpiCollectionsChip => demoMode ? '6 receipts' : '';
  String get kpiArChip => demoMode
      ? '3,275.250 over 60d'
      : (kpis?.customers != null ? '${kpis!.customers} customers' : '');
  String get kpiLowChip => demoMode
      ? '2 out of stock'
      : (kpis?.items != null ? '${kpis!.items} items tracked' : '');

  // ── stock count / cart (demo dataset) ──────────────────────────────
  int countExpected(int id) => _countRows[id]?.expected ?? 0;
  int? countValue(int id) => counts[id];
  int get countedLines => counts.length;
  int get countVar => counts.entries.where((e) => e.value != countExpected(e.key)).length;
  String get countWarehouseName {
    if (demoMode) return 'Main WH · Tubli';
    for (final w in _warehouses) {
      if (w.id == _countWarehouse) return w.name;
    }
    return wh;
  }

  /// Unit price of a line: the user's manual price, else the list price.
  double linePrice(CartLine l) => l.price ?? productById(l.pid).price;

  /// Sets (or with null, resets to the list price) the unit price of [pid] on
  /// the quotation ([quote]) or the cash sale.
  void setLinePrice(int pid, double? price, {required bool quote}) {
    for (final l in quote ? quoteLines : cart) {
      if (l.pid == pid) l.price = price;
    }
    // The document body changed, so a retry must not replay the old request.
    if (quote) {
      _quoteIdemKey = null;
    } else {
      _draftIdemKey = null;
    }
    notifyListeners();
  }

  double get subtotal => cart.fold(0, (a, l) => a + linePrice(l) * l.qty);
  double get vat => subtotal * 0.10;
  double get total => subtotal + vat;

  /// Quotation line totals (same 10% VAT basis as the cash sale preview).
  /// These are indicative only — the server prices the document on save.
  double get quoteSubtotal => quoteLines.fold(0, (a, l) => a + linePrice(l) * l.qty);
  double get quoteVat => quoteSubtotal * 0.10;
  double get quoteTotal => quoteSubtotal + quoteVat;

  // Barcode scan result
  Product? scanned;
  bool scanLoading = false;

  // ══════════════════════════════════════════════════════════════════
  //  Permissions (menu-driven in live mode, role-driven in demo)
  // ══════════════════════════════════════════════════════════════════
  /// Rights for a Mobile App feature (see models/permissions.dart). Demo mode
  /// has no server, so it uses the demo role picked in Settings.
  Rights rights(String feature) => permsReady ? _perms.of(feature) : Rights.none;
  bool _can(String feature, bool Function(Rights r) right) => permsReady && right(_perms.of(feature));

  /// Live sessions show a page only once the user's rights are known (from the
  /// server, or the copy saved on the phone) — never "everything" while they
  /// load or when they can't be read.
  bool get permsReady => demoMode || _perms.known;

  /// The pages this user may open, in menu order — ONE list for the Home
  /// workspace grid and the More screen, so they can't disagree. Titles are
  /// translation keys.
  List<({IconData icon, String title, String subtitle, VoidCallback onTap, Screen screen})> get pages => [
        if (mProducts) (icon: Icons.inventory_2_outlined, title: 'Products', subtitle: 'Search, prices, stock, photos', onTap: () => nav(Screen.products), screen: Screen.products),
        if (mCustomers) (icon: Icons.people_outline, title: 'Customers', subtitle: 'Directory & balances', onTap: () => nav(Screen.customers), screen: Screen.customers),
        if (mSuppliers) (icon: Icons.local_shipping_outlined, title: 'Suppliers', subtitle: 'Directory & account statements', onTap: goSuppliers, screen: Screen.suppliers),
        if (mStatements) (icon: Icons.description_outlined, title: 'Statements', subtitle: 'Customer & supplier statements', onTap: openStatementPicker, screen: Screen.statementPicker),
        if (mSale) (icon: Icons.receipt_long_outlined, title: 'Cash Sale', subtitle: 'Scan items, save as draft', onTap: () => newSale(), screen: Screen.invoice),
        if (mQuoteNew) (icon: Icons.request_quote_outlined, title: 'Quotation', subtitle: 'Save & send as PDF', onTap: () => newQuotation(), screen: Screen.quotation),
        if (mQuotes) (icon: Icons.history, title: 'Saved quotations', subtitle: 'View past quotations, download PDF', onTap: openQuoteHistory, screen: Screen.quotations),
        if (mCount) (icon: Icons.checklist_rounded, title: 'Stock Count', subtitle: 'Expected vs counted, variance', onTap: goCount, screen: Screen.count),
        if (mStockAlerts) (icon: Icons.warning_amber_rounded, title: 'Stock alerts', subtitle: 'Low stock & dead stock', onTap: goLow, screen: Screen.low),
        if (mReports) (icon: Icons.show_chart, title: 'Reports', subtitle: 'Sales & purchases, top lists', onTap: goReports, screen: Screen.reports),
        if (mAnalytics || mFinance) (icon: Icons.insights_outlined, title: 'Business health', subtitle: 'Aging, cash, margin, trends', onTap: openManagerReports, screen: Screen.managerReports),
        if (mLabels) (icon: Icons.qr_code_2_outlined, title: 'Print Labels', subtitle: 'Barcode & shelf labels', onTap: openLabels, screen: Screen.labels),
        if (mDocuments) (icon: Icons.attach_file, title: 'Attach Docs', subtitle: 'Scan or upload files to a document', onTap: openAttachDocs, screen: Screen.documents),
      ];

  /// Warehouses were loaded (only for roles with stock pages) — the Home
  /// header shows the warehouse picker only then.
  bool get hasWarehouses => demoMode || _warehouses.isNotEmpty;

  // Pages (View)
  bool get mDashboard => demoMode ? true : _can(Feat.dashboard, (r) => r.view);
  bool get mProducts => demoMode ? true : _can(Feat.products, (r) => r.view);
  bool get mCustomers => demoMode ? true : _can(Feat.customers, (r) => r.view);
  bool get mSuppliers => demoMode ? role == Role.manager : _can(Feat.suppliers, (r) => r.view);
  bool get mStatements => demoMode ? true : _can(Feat.statements, (r) => r.view);
  bool get mStockAlerts => demoMode ? role != Role.salesRep : _can(Feat.stockAlerts, (r) => r.view);
  bool get mReports => demoMode ? role == Role.manager : _can(Feat.reports, (r) => r.view);

  /// Manager reports (v1.4.5+) split by RBAC gate.
  /// `MobileReports` → analytics; `MobileFinanceReports` → money/profit/cost.
  bool get mAnalytics => mReports;
  bool get mFinance => demoMode ? role == Role.manager : _can(Feat.financeReports, (r) => r.view);

  /// Print Labels (v1.4.7) — page `MobileLabels` View; the Print button needs Print.
  bool get mLabels => demoMode ? role != Role.salesRep : _can(Feat.labels, (r) => r.view);
  bool get mLabelPrint => demoMode ? mLabels : _can(Feat.labels, (r) => r.print);

  /// Attach Docs (1.6.x) — `MobileDocuments`; attach/delete come per document from /documents/lookup.
  bool get mDocuments => demoMode ? role != Role.salesRep : _can(Feat.documents, (r) => r.view);

  // Stock count: View opens the sheet, Create submits (and the "Count" buttons).
  bool get mCount => demoMode ? role != Role.salesRep : _can(Feat.stockCount, (r) => r.view);
  bool get mCountSubmit => demoMode ? mCount : _can(Feat.stockCount, (r) => r.create);

  // Cash sale: the screen only makes drafts, so it needs Create; Print = its PDF.
  bool get mSale => demoMode ? role != Role.storekeeper : _can(Feat.cashSales, (r) => r.view && r.create);
  bool get mSalePrint => demoMode ? mSale : _can(Feat.cashSales, (r) => r.print);

  // Quotations: View = saved list, Create = new quotation, Print = PDF download/share.
  bool get mQuotes => demoMode ? role != Role.storekeeper : _can(Feat.quotations, (r) => r.view);
  bool get mQuoteNew => demoMode ? mQuotes : _can(Feat.quotations, (r) => r.create);
  bool get mQuotePrint => demoMode ? mQuotes : _can(Feat.quotations, (r) => r.print);

  // Products: Edit = barcode / price and photos.
  bool get mProductEdit => demoMode ? true : _can(Feat.products, (r) => r.edit);

  /// Whether the user may be on [s]; used to leave a page whose permission
  /// was just taken away.
  bool _screenAllowed(Screen s) => switch (s) {
        Screen.products || Screen.product || Screen.scan => mProducts,
        Screen.customers || Screen.customer => mCustomers,
        Screen.managerReports => mAnalytics || mFinance,
        Screen.documents => mDocuments,
        Screen.suppliers => mSuppliers,
        Screen.statementPicker || Screen.statement => mStatements,
        Screen.invoice => mSale,
        Screen.quotation => mQuoteNew,
        Screen.quotations => mQuotes,
        Screen.count => mCount,
        Screen.low => mStockAlerts,
        Screen.reports => mReports,
        Screen.labels => mLabels,
        _ => true,
      };

  bool get showNav => const {
        Screen.home,
        Screen.products,
        Screen.customers,
        Screen.more,
      }.contains(screen);

  // ══════════════════════════════════════════════════════════════════
  //  Session lifecycle
  // ══════════════════════════════════════════════════════════════════
  String _deviceName() {
    try {
      return 'LeoCore Mobile · ${Platform.operatingSystem}';
    } catch (_) {
      return 'LeoCore Mobile';
    }
  }

  /// Friendly label for the current device (Settings → registered devices).
  String get deviceLabel {
    try {
      final os = Platform.operatingSystem;
      return '${os[0].toUpperCase()}${os.substring(1)} device';
    } catch (_) {
      return 'This device';
    }
  }

  Future<void> _restoreSession() async {
    serverHistory = await _store.serverHistory;
    final s = await _store.serverUrl;
    if (s != null && s.isNotEmpty) {
      serverUrl = s; // last server used
    } else if (serverHistory.isNotEmpty) {
      serverUrl = serverHistory.first; // last successful login
    }
    final savedLang = await _store.lang;
    if (savedLang == 'en' || savedLang == 'ar') lang = savedLang!;
    biometrics = await _store.bioEnabled;
    biometricAvailable = await _bio.available();
    notifyListeners();

    final access = await _store.accessToken;
    final refresh = await _store.refreshToken;
    final hasSession = access != null && refresh != null && access.isNotEmpty;
    if (!hasSession) return;

    // With fingerprint unlock on, hold the session locked behind a biometric
    // prompt instead of dropping straight into the app.
    if (biometrics && biometricAvailable) {
      sessionLocked = true;
      screen = Screen.login;
      notifyListeners();
      return;
    }
    await _openSession(access);
  }

  /// Activates a stored session and loads the workspace.
  Future<void> _openSession(String access) async {
    await api.useServer(serverUrl);
    api.setAccessToken(access);
    demoMode = false;
    sessionLocked = false;
    screen = Screen.home;
    notifyListeners();
    // Renew first: it restarts the sign-in lifetime on every app open, and the
    // loads below then start with a fresh access token instead of all racing
    // into 401s.
    if (!await _renewSession()) return;
    try {
      me = await _auth.me();
      notifyListeners();
    } catch (_) {/* token may still be valid for data */}
    await _loadAll();
  }

  void _onSessionExpired() {
    _dropToLogin('Your session expired. Please sign in again.');
  }

  /// The server revoked this user's mobile access (403 MOBILE_ACCESS_DISABLED).
  /// Clear tokens and return to login using the server's own message — no
  /// refresh attempt (the client already skips it for this code).
  void _onAccessRevoked(String message) {
    _store.clearTokens();
    _dropToLogin(message.isNotEmpty ? message : 'Your mobile access has been disabled.');
  }

  void _dropToLogin(String message) {
    _resetLists();
    demoMode = true;
    _products = null;
    _customers = null;
    kpis = null;
    sessionLocked = false;
    screen = Screen.login;
    loginErr = false;
    loginErrMsg = message;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    _resetLists();
    dataLoading = true;
    dataError = null;
    notifyListeners();
    try {
      // 1) What may this user do? Nothing else is fetched until this is known,
      //    so a role with only Attach Docs makes no product/customer/KPI calls.
      await _loadPermissions();
      if (!_perms.known) {
        dataError = 'Could not load your permissions. Check the connection and tap Retry.';
        return;
      }
      notifyListeners();

      // 2) Only the data the permitted pages use.
      final needItems = mProducts || mSale || mQuoteNew || mCount || mLabels;
      final needCustomers = mCustomers || mSale || mQuoteNew;
      final needWarehouses = needItems || mStockAlerts;
      final results = await Future.wait<Object>([
        needItems
            ? _repo.products(pageSize: 200).catchError((Object e) => e is ApiException && e.isForbidden ? <Product>[] : throw e)
            : Future.value(<Product>[]),
        needCustomers
            ? _repo.customers(pageSize: 200).catchError((Object e) => e is ApiException && e.isForbidden ? <Customer>[] : throw e)
            : Future.value(<Customer>[]),
        mDashboard ? _repo.kpis().catchError((_) => const KpiData()) : Future.value(const KpiData()),
        needItems ? _repo.categories().catchError((_) => <({int id, String name})>[]) : Future.value(<({int id, String name})>[]),
        needWarehouses
            ? _repo.warehouses().catchError((_) => <({int id, String code, String name})>[])
            : Future.value(<({int id, String code, String name})>[]),
      ]);
      _products = results[0] as List<Product>;
      _customers = results[1] as List<Customer>;
      kpis = results[2] as KpiData;
      final cats = results[3] as List<({int id, String name})>;
      _liveCategories = [for (final c in cats) c.name];
      _categoryIds = {for (final c in cats) c.name: c.id};
      _warehouses = results[4] as List<({int id, String code, String name})>;
      if (_warehouses.isNotEmpty) {
        warehouseId = _warehouses.first.id;
        wh = _warehouses.first.name;
      }
      // Real 7-day trend for the Home chart (dashboard only).
      if (mDashboard) {
        final now = DateTime.now();
        final fmt = DateFormat('yyyy-MM-dd');
        try {
          final r = await _repo.salesReport(
            from: fmt.format(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6))),
            to: fmt.format(now),
          );
          homeTrend = r.trend;
        } catch (_) {
          homeTrend = [];
        }
      }
      if (_products!.isNotEmpty) pid = _products!.first.id;
      if (_customers!.isNotEmpty) cid = _customers!.first.id;

      // A role with one page and no dashboard (e.g. document scanning only)
      // starts on that page instead of an empty Home.
      if (screen == Screen.home && !mDashboard) {
        final ps = pages;
        if (ps.length == 1) ps.first.onTap();
      }
    } on ApiException catch (e) {
      dataError = e.message;
    } catch (_) {
      dataError = 'Could not load data from the server.';
    } finally {
      dataLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryLoad() => _loadAll();

  // ══════════════════════════════════════════════════════════════════
  //  Actions
  // ══════════════════════════════════════════════════════════════════
  void nav(Screen s) {
    if (!_screenAllowed(s)) {
      showToast("You don't have access to this page.");
      return;
    }
    screen = s;
    notifyListeners();
  }

  DateTime? _lastBackPress;

  /// Handle the Android system back button. Returns true if the app consumed it
  /// (closed a sheet or navigated); false means "we're at a root screen — the
  /// caller should apply double-tap-to-exit".
  bool handleSystemBack() {
    // 1) Close any open overlay/sheet first.
    if (editSheet) {
      closeEdit();
      return true;
    }
    if (filterSheet) {
      closeFilter();
      return true;
    }
    if (whSheet) {
      closeWhSheet();
      return true;
    }
    if (screen == Screen.scan) {
      if (scanFound) {
        scanFound = false;
        scanned = null;
        notifyListeners();
      } else {
        closeScan();
      }
      return true;
    }
    if (countSubmitted) {
      closeCountDone();
      return true;
    }

    // 2) Screen-level back navigation.
    switch (screen) {
      case Screen.login:
      case Screen.home:
        return false; // root → double-tap to exit
      case Screen.product:
        nav(Screen.products);
        return true;
      case Screen.customer:
        nav(Screen.customers);
        return true;
      case Screen.statement:
        nav(statementReturn);
        return true;
      case Screen.receipt:
        nav(savedDoc?.status == 'Open' ? Screen.quotation : Screen.invoice);
        return true;
      case Screen.quotation:
      case Screen.invoice:
        leaveDoc();
        return true;
      case Screen.quotations:
        closeQuoteHistory();
        return true;
      case Screen.settings:
      case Screen.managerReports:
      case Screen.labels:
      case Screen.documents:
        nav(Screen.more);
        return true;
      case Screen.products:
      case Screen.customers:
      case Screen.more:
      case Screen.suppliers:
      case Screen.statementPicker:
      case Screen.count:
      case Screen.low:
      case Screen.reports:
        nav(Screen.home);
        return true;
      case Screen.scan:
        closeScan();
        return true;
    }
  }

  /// Double-tap-to-exit gate for root screens. Returns true when the app should
  /// actually close (a second back within 2s).
  bool confirmExit() {
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastBackPress = now;
    showToast(t('Press back again to exit'));
    return false;
  }

  void showToast(String msg) {
    _toastTimer?.cancel();
    toast = msg;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toast = null;
      notifyListeners();
    });
  }

  // login
  void setLoginUser(String v) {
    loginUser = v;
    notifyListeners();
  }

  void setLoginPass(String v) {
    loginPass = v;
    loginErr = false;
    loginErrMsg = null;
    notifyListeners();
  }

  void setServerUrl(String v) {
    serverUrl = v;
    notifyListeners();
    // Remember the last server the user entered (even before a successful login).
    _store.setServerUrl(v);
  }

  /// Choose a saved server from the dropdown.
  void pickServer(String url) {
    serverUrl = url;
    _store.setServerUrl(url);
    notifyListeners();
  }

  /// Forget a saved server (from the dropdown).
  Future<void> removeServer(String url) async {
    await _store.removeServer(url);
    serverHistory = await _store.serverHistory;
    notifyListeners();
  }

  void toggleKeep() {
    keep = !keep;
    notifyListeners();
  }

  /// Live sign-in against the configured server.
  Future<void> doLogin() async {
    if (loginPass.isEmpty) {
      loginErr = true;
      loginErrMsg = null;
      notifyListeners();
      return;
    }
    loggingIn = true;
    loginErr = false;
    loginErrMsg = null;
    notifyListeners();
    try {
      await api.useServer(serverUrl);
      await _store.setServerUrl(serverUrl);
      final res = await _auth.login(
        username: loginUser.trim(),
        password: loginPass,
        deviceName: _deviceName(),
      );
      me = res.user;
      // A fresh login is as good as a renewal — don't rotate again on the
      // first app switch (share sheet, PDF viewer, file picker…).
      _lastRenewal = DateTime.now();
      demoMode = false;
      loggingIn = false;
      loginPass = '';
      screen = Screen.home;
      // Remember this server for the dropdown next time.
      await _store.addServer(serverUrl.trim());
      serverHistory = await _store.serverHistory;
      notifyListeners();
      // Single-device login: tell the user if another device was signed out.
      if (res.sessionMessage != null) showToast(res.sessionMessage!);
      await _loadAll();
    } on ApiException catch (e) {
      loggingIn = false;
      loginErr = true;
      loginErrMsg = e.message;
      notifyListeners();
    } catch (_) {
      loggingIn = false;
      loginErr = true;
      loginErrMsg = 'Something went wrong. Please try again.';
      notifyListeners();
    }
  }

  /// Fingerprint unlock — prompts for a biometric, then reopens the stored
  /// session. Requires a prior password sign-in (we never store the password).
  Future<void> doBiometric() async {
    if (!biometricAvailable) {
      biometricAvailable = await _bio.available();
      if (!biometricAvailable) {
        showToast(t('No fingerprint enrolled on this device'));
        return;
      }
    }
    final access = await _store.accessToken;
    final refresh = await _store.refreshToken;
    if (access == null || refresh == null || access.isEmpty) {
      showToast(t('Sign in with your password first'));
      return;
    }
    final res = await _bio.authenticate('Unlock LeoCore ERP');
    if (!res.ok) {
      if (res.error != null) showToast(res.error!);
      return;
    }
    loginErr = false;
    loginErrMsg = null;
    await _openSession(access);
  }

  Future<void> doLogout() async {
    // Clear credentials on sign-out (server address is intentionally kept).
    loginUser = '';
    loginPass = '';
    loginErr = false;
    loginErrMsg = null;
    if (!demoMode) {
      await _auth.logout();
    }
    sessionLocked = false;
    demoMode = true;
    _products = null;
    _customers = null;
    _statement = null;
    _ledger = null;
    kpis = null;
    me = null;
    _perms = MobilePermissions.unknown;
    _resetLists();
    nav(Screen.login);
  }

  // products
  void setQuery(String v) {
    query = v;
    productList.setSearch(v);
  }

  void pickCat(String c) {
    if (cat == c) return;
    cat = c;
    productList.refresh();
  }

  void clearSearch() {
    query = '';
    cat = 'All';
    productList.search = '';
    productList.refresh();
  }

  Future<void> doRefresh() => productList.refresh();

  // product detail
  void openProduct(int id) {
    pid = id;
    prodTab = 'info';
    _ledger = null;
    _productDetail = null;
    nav(Screen.product);
    if (!demoMode) {
      _loadProductDetail(id);
      _loadLedger(id);
    }
  }

  Future<void> _loadProductDetail(int id) async {
    try {
      _productDetail = await _repo.product(id);
      notifyListeners();
    } catch (_) {/* keep the list item */}
  }

  Future<void> _loadLedger(int id) async {
    ledgerLoading = true;
    notifyListeners();
    try {
      _ledger = await _repo.stockLedger(itemId: id);
      // If the product detail didn't carry on-hand qty, the newest ledger row's
      // running balance is the current stock — fold it in as a fallback.
      if (_ledger!.isNotEmpty &&
          _productDetail != null &&
          _productDetail!.id == id &&
          _productDetail!.stock <= kUnknownStock) {
        final bal = _ledger!.first.bal;
        _productDetail = _productDetail!.copyWith(stock: bal, wh: [('On hand', bal)]);
      }
    } catch (_) {
      _ledger = [];
    }
    ledgerLoading = false;
    notifyListeners();
  }

  void setProdTab(String t) {
    prodTab = t;
    notifyListeners();
  }

  void openEdit() {
    editSheet = true;
    editBarcode = product.barcode;
    editPrice = MockData.money(product.price);
    notifyListeners();
  }

  void setEditBarcode(String v) {
    editBarcode = v;
    notifyListeners();
  }

  void setEditPrice(String v) {
    editPrice = v;
    notifyListeners();
  }

  void closeEdit() {
    editSheet = false;
    notifyListeners();
  }

  Future<void> saveEdit() async {
    editSheet = false;
    notifyListeners();
    if (!demoMode) {
      try {
        await _repo.updateProduct(
          product.id,
          barcode: editBarcode,
          defaultPrice: double.tryParse(editPrice.replaceAll(',', '')),
        );
        _products = await _repo.products(pageSize: 200);
        showToast(t('Product updated'));
      } on ApiException catch (e) {
        showToast(e.message);
      } catch (_) {
        showToast(t('Could not update product'));
      }
    } else {
      showToast(t('Product updated'));
    }
  }

  // cart — adds to whichever document is currently being built
  void addToCart(int pid, [String? note]) {
    if (activeDoc == 'quotation') {
      final existing = quoteLines.where((l) => l.pid == pid).toList();
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        quoteLines.add(CartLine(pid, 1));
      }
      showToast(note ?? t('Added to quotation'));
      return;
    }
    final existing = cart.where((l) => l.pid == pid).toList();
    if (existing.isNotEmpty) {
      existing.first.qty += 1;
    } else {
      cart.add(CartLine(pid, 1));
    }
    showToast(note ?? t('Added to memo'));
  }

  void addCurrentToCart() => addToCart(product.id);

  // ── item picker (cash sale / quotation) ────────────────────────────
  String pickQuery = '';
  List<Product> _pickRemote = const [];
  bool pickLoading = false;
  Timer? _pickDebounce;

  static bool _productMatches(Product p, String q) =>
      p.id.toString() == q ||
      p.code.toLowerCase().contains(q) ||
      p.name.toLowerCase().contains(q) ||
      p.brand.toLowerCase().contains(q) ||
      p.cat.toLowerCase().contains(q) ||
      p.barcode.toLowerCase().contains(q);

  /// Loaded products matching the query by id, code, name, brand, category or
  /// barcode, plus server matches that aren't in the loaded page.
  List<Product> get pickProductRows {
    final q = pickQuery.trim().toLowerCase();
    if (q.isEmpty) return products;
    final local = products.where((p) => _productMatches(p, q)).toList();
    final seen = local.map((p) => p.id).toSet();
    return [...local, ..._pickRemote.where((p) => seen.add(p.id))];
  }

  /// Quantity of [pid] already on the document being built.
  int pickedQty(int pid) {
    final lines = activeDoc == 'quotation' ? quoteLines : cart;
    return lines.where((l) => l.pid == pid).fold(0, (a, l) => a + l.qty);
  }

  void openPicker() {
    pickQuery = '';
    _pickRemote = const [];
    pickLoading = false;
  }

  void setPickQuery(String v) {
    pickQuery = v;
    notifyListeners();
    _pickDebounce?.cancel();
    final q = v.trim();
    if (demoMode || q.isEmpty) {
      _pickRemote = const [];
      return;
    }
    _pickDebounce = Timer(const Duration(milliseconds: 350), () async {
      pickLoading = true;
      notifyListeners();
      try {
        final rows = await _repo.products(search: q, pageSize: 50);
        if (pickQuery.trim() == q) _pickRemote = rows;
      } catch (_) {/* local matches still show */}
      if (pickQuery.trim() == q) pickLoading = false;
      notifyListeners();
    });
  }

  /// Adds [p] to the current document. Server results outside the loaded page
  /// are cached so the line can resolve its product (name / price).
  void addPicked(Product p) {
    if (!demoMode && !products.any((e) => e.id == p.id)) {
      _products = [...products, p];
    }
    addToCart(p.id);
  }
  void incLine(int pid) => addToCart(pid, 'Quantity updated');

  void decLine(int pid) {
    for (final l in cart) {
      if (l.pid == pid) l.qty -= 1;
    }
    cart = cart.where((l) => l.qty > 0).toList();
    notifyListeners();
  }

  // warehouse
  void openWhSheet() {
    whSheet = true;
    notifyListeners();
  }

  void closeWhSheet() {
    whSheet = false;
    notifyListeners();
  }

  void pickWh(String name, [int? id]) {
    wh = name;
    if (id != null) warehouseId = id;
    whSheet = false;
    notifyListeners();
  }

  // filter
  void openFilter() {
    filterSheet = true;
    notifyListeners();
  }

  void closeFilter() {
    filterSheet = false;
    notifyListeners();
  }

  void applyFilter() {
    filterSheet = false;
    showToast(t('Filters applied'));
  }

  // customers
  void openCustomer(int id) {
    cid = id;
    _statement = null;
    nav(Screen.customer);
    if (!demoMode) _loadStatement(id);
  }

  Future<void> callCust() async {
    final phone = customer.phone.trim();
    if (phone.isEmpty) {
      showToast(t('No phone number on file'));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (!await launchUrl(uri)) showToast(t('Could not open the dialer'));
  }

  Future<void> waCust() async {
    final digits = customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      showToast(t('No phone number on file'));
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showToast(t('WhatsApp is not installed'));
    }
  }

  Future<void> navCust() async {
    final q = Uri.encodeComponent(
        [customer.name, customer.area].where((s) => s.isNotEmpty).join(', '));
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showToast(t('Could not open Maps'));
    }
  }

  // ── statement PDF (download → share / print) ───────────────────────
  /// True while the statement PDF is being fetched from the server, so the
  /// Share / Print buttons can show an inline spinner.
  bool statementSharing = false; // busy while sharing
  bool statementPrinting = false; // busy while printing

  bool get statementBusy => statementSharing || statementPrinting;

  /// Validates a downloaded response is really a PDF and returns safe bytes +
  /// filename, or `null` (with an explanatory toast) if it isn't.
  ({Uint8List bytes, String filename})? _validatePdf(
      ({List<int> bytes, String filename, String contentType}) res) {
    if (res.bytes.isEmpty) {
      showToast(t('The statement came back empty'));
      return null;
    }
    // Guard: the server must actually return a PDF. If PDF export isn't
    // enabled it returns JSON — don't hand the user a broken .pdf.
    final isPdf = res.contentType.toLowerCase().contains('pdf') ||
        (res.bytes.length >= 4 &&
            res.bytes[0] == 0x25 && res.bytes[1] == 0x50 &&
            res.bytes[2] == 0x44 && res.bytes[3] == 0x46); // %PDF
    if (!isPdf) {
      showToast(t('PDF export is not enabled on your server yet'));
      return null;
    }
    final safe = res.filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return (bytes: Uint8List.fromList(res.bytes), filename: safe);
  }

  /// Path of the most recently downloaded PDF (so the UI can re-share it).
  String? lastPdfPath;

  static const _downloads = MethodChannel('leocore/downloads');

  /// Writes a private copy of the PDF (so Share can always reach the last
  /// download) and, on Android, saves it to the public Downloads folder.
  /// Returns the private file plus the Downloads URI (null on iOS or failure).
  Future<({File file, String? uri})> _savePdf(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    lastPdfPath = file.path;
    String? uri;
    if (Platform.isAndroid) {
      try {
        uri = await _downloads.invokeMethod<String>(
            'save', {'bytes': bytes, 'name': filename, 'mime': 'application/pdf'});
      } on PlatformException catch (e) {
        debugPrint('Save to Downloads failed: ${e.message}');
      }
    }
    return (file: file, uri: uri);
  }

  // ── picture save / share (full-screen photo viewer) ───────────────────

  /// File name for a downloaded product picture: "<code>_<n>.<ext>", with the
  /// extension taken from the server file so a PNG stays a PNG.
  static String pictureFileName(String code, String url, int index) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    var ext = dot > path.lastIndexOf('/') ? path.substring(dot + 1).toLowerCase() : 'jpg';
    if (!const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) ext = 'jpg';
    final base = (code.isEmpty ? 'product' : code).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${base}_${index + 1}.$ext';
  }

  static String _pictureMime(String filename) {
    final f = filename.toLowerCase();
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.webp')) return 'image/webp';
    if (f.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<File> _pictureTemp(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Saves a picture to the phone. Android: Pictures/LeoCore, where it shows
  /// in the gallery (no permission needed on Android 10+). iOS has no public
  /// folder, so the share sheet opens — "Save Image" puts it in Photos.
  Future<void> savePicture(Uint8List bytes, String filename) async {
    final mime = _pictureMime(filename);
    if (Platform.isAndroid) {
      try {
        await _downloads.invokeMethod<String>(
            'save', {'bytes': bytes, 'name': filename, 'mime': mime, 'folder': 'pictures'});
        showToast('${t('Saved to Pictures')} · $filename');
        return;
      } on PlatformException catch (e) {
        debugPrint('Save picture failed: ${e.message}');
        showToast(t('Could not save the picture'));
        return;
      }
    }
    final file = await _pictureTemp(bytes, filename);
    await Share.shareXFiles([XFile(file.path, mimeType: mime, name: filename)]);
  }

  /// Opens the system share sheet with the picture (WhatsApp, mail, …).
  Future<void> sharePicture(Uint8List bytes, String filename, {String? text}) async {
    final file = await _pictureTemp(bytes, filename);
    await Share.shareXFiles([XFile(file.path, mimeType: _pictureMime(filename), name: filename)], text: text);
  }

  /// Saves the PDF to the phone's public Downloads folder and opens it in the
  /// default PDF app. On iOS (no Downloads folder) it is kept in the app's
  /// documents directory and opened from there. Falls back to a prompt (install
  /// a viewer / share) when nothing can open it.
  Future<void> _deliverPdf(Uint8List bytes, String filename) async {
    final (:file, :uri) = await _savePdf(bytes, filename);
    if (Platform.isAndroid) {
      if (uri != null) {
        String? opened;
        try {
          opened = await _downloads.invokeMethod<String>('open', {'uri': uri, 'mime': 'application/pdf'});
        } on PlatformException catch (e) {
          debugPrint('Open PDF failed: ${e.message}');
        }
        if (opened == 'done') {
          showToast('${t('Saved to Downloads')} · $filename');
          return;
        }
        await _promptNoPdfViewer(file.path, filename, noViewer: opened == 'noApp', inDownloads: true);
        return;
      }
      // Couldn't write to Downloads — fall through and open the private copy.
    }
    ResultType? type;
    try {
      final res = await OpenFilex.open(file.path, type: 'application/pdf');
      type = res.type;
    } catch (_) {
      type = null;
    }
    if (type == ResultType.done) {
      showToast('${t('Downloaded')} · $filename');
      return;
    }
    // No app can open a PDF (or the open handler failed) — prompt the user to
    // install a viewer or share the file, instead of failing silently.
    final noViewer = type == null || type == ResultType.noAppToOpen;
    await _promptNoPdfViewer(file.path, filename, noViewer: noViewer);
  }

  /// Shown when the phone has no PDF viewer associated: offers to install one
  /// or share the file, so the download can't dead-end in an error.
  Future<void> _promptNoPdfViewer(String path, String filename,
      {required bool noViewer, bool inDownloads = false}) async {
    Future<void> share() async {
      try {
        await Share.shareXFiles([XFile(path, mimeType: 'application/pdf', name: filename)]);
      } catch (_) {
        showToast('${t('Saved')} · $filename');
      }
    }

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      await share();
      return;
    }
    final choice = await showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(t('No PDF viewer'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          (inDownloads ? '${t('The file was saved to your Downloads folder.')}\n\n' : '') +
              (noViewer
                  ? t('This phone has no app to open PDF files. Install a free PDF viewer to open statements and documents, or share this file to another app.')
                  : t('Could not open the PDF here. Install a PDF viewer, or share this file to another app.')),
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, 'share'), child: Text(t('Share'))),
          TextButton(
            onPressed: () => Navigator.pop(dctx, 'install'),
            child: Text(t('Get a PDF viewer'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (choice == 'install') {
      await _openPdfViewerStore();
      // Keep the saved file reachable — offer the share sheet after they return.
    } else if (choice == 'share') {
      await share();
    } else {
      showToast('${t(inDownloads ? 'Saved to Downloads' : 'Saved')} · $filename');
    }
  }

  /// Opens the platform app store at a PDF-viewer search so the user can
  /// install one, then associate it with PDF files.
  Future<void> _openPdfViewerStore() async {
    final primary = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/search?term=pdf%20viewer')
        : Uri.parse('market://search?q=pdf%20viewer&c=apps');
    final web = Uri.parse(Platform.isIOS
        ? 'https://apps.apple.com/search?term=pdf%20viewer'
        : 'https://play.google.com/store/search?q=pdf%20viewer&c=apps');
    try {
      if (await launchUrl(primary, mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* fall through */}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      showToast(t('Could not open the store'));
    }
  }

  /// Shares the most recently downloaded PDF via the system share sheet.
  Future<void> shareLastPdf() async {
    final p = lastPdfPath;
    if (p == null) return;
    await Share.shareXFiles([XFile(p, mimeType: 'application/pdf')]);
  }

  Future<({Uint8List bytes, String filename})?> _fetchStatementPdf() async {
    final id = statementParty == 'supplier' ? supplierId : cid;
    final asOn = statementAsOn == null ? null : DateFormat('yyyy-MM-dd').format(statementAsOn!);
    final res = await _repo.statementPdf(statementParty, id, asOn: asOn);
    return _validatePdf(res);
  }

  /// Downloads the statement PDF and opens it — the primary statement action.
  Future<void> downloadStmt() async {
    if (demoMode) {
      showToast(t('Statement PDF is available after live sign-in'));
      return;
    }
    if (statementBusy) return;
    statementSharing = true;
    notifyListeners();
    try {
      final pdf = await _fetchStatementPdf();
      if (pdf == null) return;
      await _deliverPdf(pdf.bytes, pdf.filename);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not generate the statement PDF'));
    } finally {
      statementSharing = false;
      notifyListeners();
    }
  }

  /// Saves the PDF to Downloads first, then opens the share sheet with that
  /// saved file (iOS / no Downloads: shares the private copy).
  Future<void> _sharePdf(Uint8List bytes, String filename, String subject) async {
    final (:file, :uri) = await _savePdf(bytes, filename);
    if (uri != null) {
      await _downloads.invokeMethod<String>('share', {'uri': uri, 'mime': 'application/pdf', 'subject': subject});
    } else {
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: subject);
    }
  }

  Future<void> shareStmt() async {
    if (demoMode) {
      showToast(t('Statement PDF is available after live sign-in'));
      return;
    }
    if (statementBusy) return;
    statementSharing = true;
    notifyListeners();
    ({Uint8List bytes, String filename})? pdf;
    try {
      pdf = await _fetchStatementPdf();
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (e) {
      debugPrint('Statement PDF fetch failed: $e');
      showToast(t('Could not generate the statement PDF'));
    }
    try {
      if (pdf == null) return;
      await _sharePdf(pdf.bytes, pdf.filename, 'Account statement — $statementPartyName');
    } catch (e) {
      debugPrint('Statement share failed: $e');
      showToast(t('Could not share the statement'));
    } finally {
      statementSharing = false;
      notifyListeners();
    }
  }

  /// Hands the downloaded PDF to the phone's print framework, where the user
  /// can pick a printer (or "Save as PDF").
  Future<void> printStmt() async {
    if (demoMode) {
      showToast(t('Statement PDF is available after live sign-in'));
      return;
    }
    if (statementBusy) return;
    statementPrinting = true;
    notifyListeners();
    try {
      final pdf = await _fetchStatementPdf();
      if (pdf == null) return;
      await Printing.layoutPdf(
        name: pdf.filename,
        onLayout: (_) async => pdf.bytes,
      );
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not open the print dialog'));
    } finally {
      statementPrinting = false;
      notifyListeners();
    }
  }

  // ── product photos ─────────────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();

  /// Locally captured photo awaiting (or having failed) upload, so the user
  /// still sees what they took even if the server rejects it.
  String? pendingPhotoPath;
  bool photoUploading = false;

  /// Absolute URL for a server image path, always on the address the app is
  /// signed in to. Older servers sent absolute links built from a guessed
  /// host and `https`, which the phone often couldn't reach (plain-http or LAN
  /// servers) while the API itself worked — so a link to the server's own
  /// `/Files/...` is re-pointed at [api.origin]. Other external links are kept.
  String imageUrl(String relative) {
    if (relative.isEmpty) return relative;
    if (relative.startsWith('http')) {
      final u = Uri.tryParse(relative);
      if (u == null || !u.path.startsWith('/Files/')) return relative;
      return '${api.origin}${u.path}${u.hasQuery ? '?${u.query}' : ''}';
    }
    final path = relative.startsWith('/') ? relative : '/$relative';
    return '${api.origin}$path';
  }

  Map<String, String> get imageHeaders => api.authHeaders;

  /// Takes a photo with the camera, or picks one via the Android Photo Picker
  /// (which needs no media-library permission), then uploads it.
  Future<void> addProductPhoto({required bool fromCamera}) async {
    if (demoMode) {
      showToast(t('Product photos require live sign-in'));
      return;
    }
    if (photoUploading) return;
    try {
      final XFile? shot = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (shot == null) return; // user cancelled
      pendingPhotoPath = shot.path;
      photoUploading = true;
      notifyListeners();

      final images = await _repo.uploadProductImage(pid, shot.path);
      // Refresh the detail so the new photo shows from the server.
      _productDetail = product.copyWith(images: images);
      pendingPhotoPath = null;
      showToast(t('Photo uploaded'));
    } on ApiException catch (e) {
      // The endpoint may not be enabled on every server yet — keep the photo
      // on screen and tell the user plainly rather than dropping it.
      if (e.status == 404 || e.code == 'HTTP_404') {
        showToast(t('Photo upload is not enabled on your server yet'));
      } else {
        showToast(e.message);
      }
    } catch (_) {
      showToast(t('Could not upload the photo'));
    } finally {
      photoUploading = false;
      notifyListeners();
    }
  }

  Future<void> removeProductPhoto(int imageId) async {
    if (demoMode) return;
    try {
      await _repo.deleteProductImage(pid, imageId);
      _productDetail = product.copyWith(
        images: product.images.where((i) => i.id != imageId).toList(),
      );
      showToast(t('Photo removed'));
    } on ApiException catch (e) {
      showToast(e.message);
    } finally {
      notifyListeners();
    }
  }

  // ── in-app review ──────────────────────────────────────────────────
  final InAppReview _review = InAppReview.instance;

  Future<void> rateApp() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      } else {
        await _review.openStoreListing();
      }
    } catch (_) {
      showToast(t('Could not open the store'));
    }
  }

  /// Gentle, once-per-install review prompt after a positive moment.
  Future<void> _maybeAskReview() async {
    if (demoMode) return;
    if (await _store.reviewAsked) return;
    await _store.setReviewAsked();
    try {
      if (await _review.isAvailable()) await _review.requestReview();
    } catch (_) {}
  }

  // ── in-app update ──────────────────────────────────────────────────
  bool updateAvailable = false;
  bool updateDismissed = false;

  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        updateAvailable = true;
        notifyListeners();
      }
    } catch (_) {/* not installed from Play, or offline — ignore */}
  }

  void dismissUpdate() {
    updateDismissed = true;
    notifyListeners();
  }

  Future<void> startUpdate() async {
    updateDismissed = true;
    notifyListeners();
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      showToast(t('Update could not be started'));
    }
  }

  /// Installed version, e.g. "2.12.0 (14)" — shown on More → Check for updates.
  String appVersion = '';
  bool checkingUpdate = false;

  Future<void> loadAppVersion() async {
    if (appVersion.isNotEmpty) return;
    try {
      final p = await PackageInfo.fromPlatform();
      appVersion = '${p.version} (${p.buildNumber})';
      notifyListeners();
    } catch (_) {}
  }

  static const _storeId = 'sek.leocore.erp';

  /// More → Check for updates. Android: asks Google Play and, when a newer
  /// version exists, runs Play's full-screen update right away (it downloads,
  /// installs and restarts the app; the sign-in is kept). iOS, or a copy not
  /// installed from Play: compares with the store and opens the store page.
  Future<void> checkForUpdateNow() async {
    if (checkingUpdate) return;
    checkingUpdate = true;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        AppUpdateInfo? info;
        try {
          info = await InAppUpdate.checkForUpdate();
        } catch (_) {/* not installed from Google Play */}
        if (info == null) {
          await _openStorePage();
          return;
        }
        final avail = info.updateAvailability;
        if (avail == UpdateAvailability.updateAvailable ||
            avail == UpdateAvailability.developerTriggeredUpdateInProgress) {
          updateAvailable = true;
          updateDismissed = true; // the banner/dialog isn't needed any more
          checkingUpdate = false;
          notifyListeners();
          try {
            await InAppUpdate.performImmediateUpdate();
          } catch (_) {
            await _openStorePage();
          }
          return;
        }
        showToast(t('You have the latest version'));
      } else {
        await _checkAppStore();
      }
    } finally {
      checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> _checkAppStore() async {
    try {
      final res = await Dio().get<dynamic>(
        'https://itunes.apple.com/lookup',
        queryParameters: {'bundleId': _storeId, 't': DateTime.now().millisecondsSinceEpoch},
        options: Options(responseType: ResponseType.plain),
      );
      final m = jsonDecode(res.data.toString()) as Map<String, dynamic>;
      final list = (m['results'] as List?) ?? const [];
      if (list.isEmpty) {
        showToast(t('Could not check for updates'));
        return;
      }
      final r = list.first as Map<String, dynamic>;
      final store = (r['version'] ?? '').toString();
      final mine = (await PackageInfo.fromPlatform()).version;
      if (_isNewer(store, mine)) {
        final url = (r['trackViewUrl'] ?? '').toString();
        if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        showToast(t('You have the latest version'));
      }
    } catch (_) {
      showToast(t('Could not check for updates'));
    }
  }

  static bool _isNewer(String a, String b) {
    List<int> p(String v) => v.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d > 0;
    }
    return false;
  }

  Future<void> _openStorePage() async {
    final market = Uri.parse('market://details?id=$_storeId');
    final web = Uri.parse('https://play.google.com/store/apps/details?id=$_storeId');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      showToast(t('Could not check for updates'));
    }
  }

  // scan
  Screen _scanReturn = Screen.home; // where "close" returns after scanning

  void openScan() {
    scanFound = false;
    scanned = null;
    scanLoading = false;
    _scanReturn = showNav ? screen : Screen.home;
    nav(Screen.scan);
  }

  void closeScan() {
    scanFound = false;
    scanned = null;
    nav(_scanReturn);
  }

  /// Handle a scanned/entered code — look the product up (live API or the demo
  /// dataset) and surface the match sheet.
  Future<void> onBarcode(String code) async {
    if (scanLoading || scanFound) return; // debounce repeated detections
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    scanLoading = true;
    notifyListeners();
    Product? found;
    try {
      if (demoMode) {
        final matches = MockData.products.where((p) => p.barcode == trimmed).toList();
        found = matches.isNotEmpty ? matches.first : MockData.products[5];
      } else {
        found = await _repo.productByBarcode(trimmed);
      }
    } on ApiException catch (e) {
      found = null;
      scanLoading = false;
      showToast(e.status == 404 ? '${t('No product matches')} "$trimmed"' : e.message);
      notifyListeners();
      return;
    } catch (_) {
      found = null;
      scanLoading = false;
      showToast('${t('No product matches')} "$trimmed"');
      notifyListeners();
      return;
    }
    scanned = found;
    scanFound = true;
    scanLoading = false;
    notifyListeners();
  }

  /// Demo/manual convenience — simulate a successful scan.
  void simulateScan() => onBarcode(demoMode ? MockData.products[5].barcode : '');

  void openScanned() {
    if (scanned != null) openProduct(scanned!.id);
  }

  void addScanned() {
    if (scanned != null) addToCart(scanned!.id);
    scanFound = false;
    nav(Screen.invoice);
  }

  /// Scanned during a count: +1 for that item, and show it in the list (its
  /// expected quantity comes with the row).
  void countScanned() {
    final p = scanned;
    countSubmitted = false;
    scanFound = false;
    if (p != null && countStarted) {
      counts[p.id] = (counts[p.id] ?? 0) + 1;
      _countIdemKey = null;
      if (!_countRows.containsKey(p.id)) {
        countQuery = p.code.isNotEmpty ? p.code : p.name;
        countList.search = countQuery;
        countList.refresh();
      }
    }
    nav(Screen.count);
  }

  // stock alerts (low / dead)
  void goLow() {
    nav(Screen.low);
    if (!demoMode && (_lowStock == null || _deadStock == null)) _loadStockAlerts();
  }

  Future<void> _loadStockAlerts() async {
    stockAlertsLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.lowStock().catchError((_) => <StockRowData>[]),
        _repo.deadStock().catchError((_) => <StockRowData>[]),
      ]);
      _lowStock = results[0];
      _deadStock = results[1];
    } catch (_) {
      _lowStock ??= [];
      _deadStock ??= [];
    }
    stockAlertsLoading = false;
    notifyListeners();
  }

  // stock count
  void goCount() {
    countSubmitted = false;
    nav(Screen.count);
  }

  void startCount() {
    if (!demoMode) {
      final w = warehouseId > 0 ? warehouseId : (_warehouses.isNotEmpty ? _warehouses.first.id : 0);
      if (w <= 0) {
        showToast(t('Select a warehouse first'));
        return;
      }
      _countWarehouse = w;
    }
    counts = demoMode ? {1: 118, 3: 96, 5: 19, 6: 8} : {};
    _countRows.clear();
    countQuery = '';
    countDocNumber = null;
    countAdjusted = 0;
    _countIdemKey = null;
    countList.reset();
    countStarted = true;
    countSubmitted = false;
    notifyListeners();
    countList.ensureLoaded();
  }

  void setCountQuery(String v) {
    countQuery = v;
    countList.setSearch(v);
  }

  void incCount(int id) {
    counts[id] = (counts[id] ?? 0) + 1;
    _countIdemKey = null;
    notifyListeners();
  }

  void decCount(int id) {
    final v = counts[id];
    if (v == null) return;
    counts[id] = v > 0 ? v - 1 : 0;
    _countIdemKey = null;
    notifyListeners();
  }

  /// Typed quantity; null clears the item (it won't be submitted).
  void setCount(int id, int? qty) {
    if (qty == null) {
      counts.remove(id);
    } else {
      counts[id] = qty < 0 ? 0 : qty;
    }
    _countIdemKey = null;
    notifyListeners();
  }

  /// Posts the count to the ERP. Only counted items are sent; the server
  /// adjusts stock in the count's warehouse for every difference.
  Future<void> submitCount() async {
    if (submittingCount) return;
    if (counts.isEmpty) {
      showToast(t('Count at least one item first'));
      return;
    }
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(t('Submit stock count?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          '${t('Items counted')}: $countedLines\n'
          '${t('With a difference')}: $countVar\n'
          '${t('Warehouse')}: $countWarehouseName\n\n'
          '${t('Stock is adjusted in the ERP for every difference. Items you did not count are left unchanged.')}',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t('Submit'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (demoMode) {
      countSubmitted = true;
      notifyListeners();
      return;
    }
    submittingCount = true;
    notifyListeners();
    // Same key on retry, so a timeout can't post the count twice.
    _countIdemKey ??= _newIdemKey();
    try {
      final r = await _repo.submitStockCount(
        warehouseId: _countWarehouse,
        lines: [for (final e in counts.entries) (itemId: e.key, countedQty: e.value)],
        idempotencyKey: _countIdemKey!,
      );
      countDocNumber = r.number;
      countAdjusted = r.adjustedLines;
      countSubmitted = true;
      _countIdemKey = null;
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not submit the count'));
    } finally {
      submittingCount = false;
      notifyListeners();
    }
  }

  void closeCountDone() {
    countStarted = false;
    countSubmitted = false;
    counts = {};
    nav(Screen.home);
  }

  // low / dead stock
  void pickStockTab(String t) {
    stockTab = t;
    notifyListeners();
  }

  // ── cash sale → save as DRAFT ──────────────────────────────────────
  /// Saves the memo to the ERP as a cash-invoice **draft**. Payment is taken
  /// later in the full app, so nothing is tendered here.
  Future<void> saveDraft() async {
    if (cart.isEmpty) {
      showToast(t('Add items to the memo first'));
      return;
    }
    if (demoMode) {
      showToast(t('Saving drafts requires live sign-in'));
      return;
    }
    final wh = warehouseId > 0 ? warehouseId : (_warehouses.isNotEmpty ? _warehouses.first.id : 0);
    if (wh <= 0) {
      showToast(t('Select a warehouse first'));
      return;
    }
    if (savingDraft) return;
    savingDraft = true;
    notifyListeners();
    // Reuse the key across retries so a timeout can't create two drafts.
    _draftIdemKey ??= _newIdemKey();
    try {
      final doc = await _repo.createCashInvoiceDraft(
        warehouseId: wh,
        lines: [for (final l in cart) (itemId: l.pid, qty: l.qty, price: l.price)],
        idempotencyKey: _draftIdemKey!,
      );
      savedDoc = doc;
      _draftIdemKey = null; // consumed — the next document gets a fresh key
      cart = [];
      nav(Screen.receipt);
      _maybeAskReview();
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not save the draft'));
    } finally {
      savingDraft = false;
      notifyListeners();
    }
  }

  bool _leavePrompting = false;

  /// Back from the cash sale / quotation. With unsaved lines, asks whether to
  /// save, discard or keep editing, so work isn't lost by an accidental back.
  Future<void> leaveDoc() async {
    final quote = screen == Screen.quotation;
    final lines = quote ? quoteLines : cart;
    final ctx = navigatorKey.currentContext;
    if (lines.isEmpty || ctx == null) {
      nav(Screen.home);
      return;
    }
    if (_leavePrompting) return; // a second back press while the dialog is up
    _leavePrompting = true;
    final String? choice;
    try {
      choice = await showDialog<String>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: Text(t('Save changes?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            quote
                ? t('This quotation has unsaved items. Save it before leaving, or discard the changes?')
                : t('This cash sale has unsaved items. Save it as a draft before leaving, or discard the changes?'),
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, 'discard'), child: Text(t('Discard'))),
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(t('Keep editing'))),
            TextButton(
              onPressed: () => Navigator.pop(dctx, 'save'),
              child: Text(t('Save'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } finally {
      _leavePrompting = false;
    }
    if (choice == 'save') {
      // Saving moves on by itself (receipt / quotation PDF); on failure the
      // lines stay and the user remains on the screen.
      await (quote ? saveQuotation() : saveDraft());
    } else if (choice == 'discard') {
      if (quote) {
        quoteLines = [];
        quoteCustomerId = 0;
        quoteCustomerQuery = '';
        _quoteIdemKey = null;
      } else {
        cart = [];
        _draftIdemKey = null;
      }
      nav(Screen.home);
    }
  }

  void newSale() {
    cart = [];
    savedDoc = null;
    activeDoc = 'cash';
    nav(Screen.invoice);
  }

  // ── quotation ──────────────────────────────────────────────────────
  Customer? get quoteCustomer => quoteCustomerId == 0
      ? null
      : customers.where((c) => c.id == quoteCustomerId).firstOrNull;

  /// Customer picker rows for the quotation screen.
  List<Customer> get quoteCustomerRows {
    final q = quoteCustomerQuery.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers
        .where((c) => c.name.toLowerCase().contains(q) || c.area.toLowerCase().contains(q))
        .toList();
  }

  void setQuoteCustomerQuery(String v) {
    quoteCustomerQuery = v;
    notifyListeners();
  }

  void pickQuoteCustomer(int id) {
    quoteCustomerId = id;
    notifyListeners();
  }

  void openQuotation() {
    activeDoc = 'quotation';
    savedDoc = null;
    nav(Screen.quotation);
  }

  void newQuotation() {
    quoteLines = [];
    quoteCustomerId = 0;
    quoteCustomerQuery = '';
    savedDoc = null;
    activeDoc = 'quotation';
    nav(Screen.quotation);
  }

  void incQuoteLine(int pid) {
    final l = quoteLines.where((e) => e.pid == pid);
    if (l.isNotEmpty) l.first.qty += 1;
    notifyListeners();
  }

  void decQuoteLine(int pid) {
    final l = quoteLines.where((e) => e.pid == pid);
    if (l.isEmpty) return;
    if (l.first.qty > 1) {
      l.first.qty -= 1;
    } else {
      quoteLines = quoteLines.where((e) => e.pid != pid).toList();
    }
    notifyListeners();
  }

  /// Saves the quotation, then downloads its PDF so it can be sent.
  Future<void> saveQuotation() async {
    if (quoteCustomerId == 0) {
      showToast(t('Choose a customer first'));
      return;
    }
    if (quoteLines.isEmpty) {
      showToast(t('Add items to the quotation first'));
      return;
    }
    if (demoMode) {
      showToast(t('Quotations require live sign-in'));
      return;
    }
    if (savingQuote) return;
    savingQuote = true;
    notifyListeners();
    _quoteIdemKey ??= _newIdemKey();
    try {
      final doc = await _repo.createQuotation(
        customerId: quoteCustomerId,
        lines: [for (final l in quoteLines) (itemId: l.pid, qty: l.qty, price: l.price)],
        idempotencyKey: _quoteIdemKey!,
      );
      savedDoc = doc;
      _quoteIdemKey = null;
      quoteLines = [];
      showToast('${t('Quotation saved')} · ${doc.number}');
      notifyListeners();
      // Immediately fetch the PDF so the user can send it.
      await downloadQuotationPdf(doc.id);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not save the quotation'));
    } finally {
      savingQuote = false;
      notifyListeners();
    }
  }

  /// Downloads the quotation PDF and opens it (falls back to the share sheet).
  Future<void> downloadQuotationPdf(int id) async {
    if (quotePdfBusy) return;
    quotePdfBusy = true;
    notifyListeners();
    try {
      final res = await _repo.quotationPdf(id);
      final pdf = _validatePdf(res);
      if (pdf == null) return;
      await _deliverPdf(pdf.bytes, pdf.filename);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not download the quotation PDF'));
    } finally {
      quotePdfBusy = false;
      notifyListeners();
    }
  }

  // ── saved quotations ───────────────────────────────────────────────
  String quoteHistoryQuery = '';
  Screen _quoteHistoryReturn = Screen.more;

  /// Quotation whose PDF is being fetched (download or share), for row spinners.
  int? quotePdfId;

  void openQuoteHistory() {
    _quoteHistoryReturn = screen == Screen.quotation ? Screen.quotation : Screen.more;
    quoteHistoryQuery = '';
    quoteList.reset(); // newest first, including one just saved
    nav(Screen.quotations);
    quoteList.ensureLoaded();
  }

  void closeQuoteHistory() => nav(_quoteHistoryReturn);

  void setQuoteHistoryQuery(String v) {
    quoteHistoryQuery = v;
    quoteList.setSearch(v);
  }

  Future<QuotationDetail?> loadQuotationDetail(int id) async {
    try {
      return await _repo.quotation(id);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not load the quotation'));
    }
    return null;
  }

  /// Saves the quotation PDF to Downloads and opens it.
  Future<void> downloadSavedQuotationPdf(int id) => _withQuotePdf(id, (pdf) => _deliverPdf(pdf.bytes, pdf.filename));

  /// Saves the quotation PDF to Downloads, then opens the share sheet.
  Future<void> shareQuotationPdf(QuotationSummary q) => _withQuotePdf(
      q.id, (pdf) => _sharePdf(pdf.bytes, pdf.filename, 'Quotation ${q.number} — ${q.customer}'));

  Future<void> _withQuotePdf(int id, Future<void> Function(({Uint8List bytes, String filename}) pdf) use) async {
    if (quotePdfId != null) return;
    quotePdfId = id;
    notifyListeners();
    try {
      final pdf = _validatePdf(await _repo.quotationPdf(id));
      if (pdf != null) await use(pdf);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not download the quotation PDF'));
    } finally {
      quotePdfId = null;
      notifyListeners();
    }
  }

  // ── manager reports (v1.4.5+) ──────────────────────────────────────
  DateTime reportFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime reportTo = DateTime.now();
  String trendGroupBy = 'day'; // day | week | month
  bool reportsBusy = false;

  AgingReport? agingRep;
  CollectionsReport? collectionsRep;
  CashPosition? cashRep;
  SalesTrendReport? trendRep;
  MarginReport? marginRep;
  TopItemsReport? topItemsRep;
  CategorySalesReport? categoryRep;
  VatReport? vatRep;
  SalesmanReport? salesmanRep;
  InventoryValuation? valuationRep;

  String get reportRangeLabel =>
      '${DateFormat('dd MMM').format(reportFrom)} – ${DateFormat('dd MMM yyyy').format(reportTo)}';

  void openManagerReports() {
    nav(Screen.managerReports);
    loadManagerReports();
  }

  Future<void> setReportRange(DateTime from, DateTime to) async {
    reportFrom = from;
    reportTo = to;
    notifyListeners();
    await loadManagerReports();
  }

  Future<void> setTrendGroupBy(String g) async {
    trendGroupBy = g;
    notifyListeners();
    if (!demoMode && mAnalytics) {
      try {
        trendRep = await _repo.salesTrend(from: _fmtD(reportFrom), to: _fmtD(reportTo), groupBy: g);
      } catch (_) {}
      notifyListeners();
    }
  }

  String _fmtD(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Loads every report the user's role is permitted to see. Each call is
  /// isolated so a 403 (missing gate) or error on one report never blocks the
  /// others.
  Future<void> loadManagerReports() async {
    if (demoMode) {
      _loadDemoReports();
      return;
    }
    reportsBusy = true;
    notifyListeners();
    final from = _fmtD(reportFrom), to = _fmtD(reportTo), asOn = _fmtD(reportTo);
    Future<void> guard(Future<void> Function() run) async {
      try {
        await run();
      } catch (_) {/* permission or transient error — leave that card empty */}
    }

    final jobs = <Future<void>>[];
    if (mAnalytics) {
      jobs.addAll([
        guard(() async => collectionsRep = await _repo.collections(from: from, to: to)),
        guard(() async => trendRep = await _repo.salesTrend(from: from, to: to, groupBy: trendGroupBy)),
        guard(() async => topItemsRep = await _repo.topItems(from: from, to: to)),
        guard(() async => categoryRep = await _repo.salesByCategory(from: from, to: to)),
        guard(() async => salesmanRep = await _repo.salesBySalesman(from: from, to: to)),
      ]);
    }
    if (mFinance) {
      jobs.addAll([
        guard(() async => agingRep = await _repo.receivablesAging(asOn: asOn)),
        guard(() async => cashRep = await _repo.cashPosition(asOn: asOn)),
        guard(() async => marginRep = await _repo.margin(from: from, to: to)),
        guard(() async => vatRep = await _repo.vat(from: from, to: to)),
        guard(() async => valuationRep = await _repo.inventoryValuation()),
      ]);
    }
    await Future.wait(jobs);
    reportsBusy = false;
    notifyListeners();
  }

  /// Sample manager-report data for the offline demo.
  void _loadDemoReports() {
    agingRep = const AgingReport(total: 41208.5, buckets: [18400, 9800, 6200, 4108.5, 2700], topDebtors: [
      AgingDebtor(customerId: 1, name: 'Gulf Mart WLL', outstanding: 9412.0, oldestDays: 47),
      AgingDebtor(customerId: 2, name: 'Al Jazira Supermarket', outstanding: 6980.25, oldestDays: 96),
      AgingDebtor(customerId: 3, name: 'Bahrain Pearl Markets', outstanding: 5455.5, oldestDays: 118),
    ]);
    cashRep = const CashPosition(totalCash: 850.0, totalBank: 63240.75, accounts: [
      (accountId: 5, name: 'NBB Current', type: 'Bank', balance: 42180.5),
      (accountId: 6, name: 'BBK Current', type: 'Bank', balance: 21060.25),
      (accountId: 9, name: 'Cash in Hand', type: 'Cash', balance: 850.0),
    ]);
    marginRep = const MarginReport(revenue: 41208.5, cost: 27940.0, grossProfit: 13268.5, marginPct: 32.2, byCategory: [
      (name: 'Rice & Grains', revenue: 12000, margin: 3600),
      (name: 'Dairy', revenue: 9200, margin: 2300),
      (name: 'Beverages', revenue: 7400, margin: 2000),
    ]);
    vatRep = const VatReport(outputVat: 1800.0, inputVat: 1100.0, netPayable: 700.0);
    valuationRep = const InventoryValuation(totalValue: 128400.0, totalQty: 41200, byCategory: [
      (name: 'Rice & Grains', value: 48000, qty: 12000),
      (name: 'Dairy', value: 32000, qty: 9800),
    ], byWarehouse: [
      (name: 'Main WH · Tubli', value: 96400, qty: 31000),
      (name: 'Sitra Store', value: 32000, qty: 10200),
    ]);
    collectionsRep = const CollectionsReport(total: 27940.0, count: 63, byMethod: [
      (label: 'Cash', amount: 12400),
      (label: 'BankTransfer', amount: 13100),
      (label: 'Cheque', amount: 2440),
    ], byDay: []);
    trendRep = const SalesTrendReport(groupBy: 'day', total: 41208.5, avgPerDay: 1373.6, points: [
      (label: 'Mon', sales: 1200, invoices: 6),
      (label: 'Tue', sales: 1850, invoices: 9),
      (label: 'Wed', sales: 980, invoices: 5),
      (label: 'Thu', sales: 2100, invoices: 11),
      (label: 'Fri', sales: 1500, invoices: 7),
      (label: 'Sat', sales: 2400, invoices: 13),
      (label: 'Sun', sales: 1760, invoices: 8),
    ]);
    topItemsRep = const TopItemsReport(by: 'value', items: [
      (itemId: 1, code: 'RICE-5KG', name: 'Mahmood Basmati Rice 5kg', qty: 612, value: 3029.4),
      (itemId: 2, code: 'MILK-2L', name: 'Almarai Full Fat Milk 2L', qty: 1840, value: 2300.0),
      (itemId: 3, code: 'TEA-200', name: 'Lipton Yellow Label 200s', qty: 486, value: 1385.1),
    ]);
    categoryRep = const CategorySalesReport(categories: [
      (name: 'Rice & Grains', sales: 12000, qty: 9800),
      (name: 'Dairy', sales: 9200, qty: 6400),
      (name: 'Beverages', sales: 7400, qty: 5100),
    ]);
    salesmanRep = const SalesmanReport(salesmen: [
      (salesmanId: 1, name: 'Yousif Mahmood', sales: 15000, invoices: 42, collections: 9000),
      (salesmanId: 2, name: 'Ahmed Salman', sales: 12400, invoices: 35, collections: 7200),
      (salesmanId: 0, name: 'Unassigned', sales: 3800, invoices: 9, collections: 1100),
    ]);
    notifyListeners();
  }

  // ── Attach Docs (1.6.x) ────────────────────────────────────────────
  String docNumber = '';
  DocLookup? docLookup;
  bool docLookupBusy = false;
  bool attachBusy = false;
  AttachResult? attachResult;
  // Files staged for upload (local path + display name).
  final List<({String path, String name})> attachFiles = [];

  /// Files already on the looked-up document (1.6.52+); null on older servers.
  List<DocAttachment>? docAttachments;

  /// Attachment being fetched or deleted, for row spinners.
  int? attachmentBusyId;

  void openAttachDocs() {
    docNumber = '';
    docLookup = null;
    docAttachments = null;
    attachResult = null;
    attachFiles.clear();
    pageShots.clear();
    docBatchMode = false;
    batchDocs.clear();
    nav(Screen.documents);
  }

  void setDocNumber(String v) {
    docNumber = v;
    // Editing the number invalidates a previous lookup.
    if (docLookup != null) {
      docLookup = null;
      docAttachments = null;
    }
    notifyListeners();
  }

  /// Verify the document exists before the user uploads (§2.1).
  Future<void> lookupDocument() async {
    final number = docNumber.trim();
    if (number.isEmpty) {
      showToast(t('Enter a document number'));
      return;
    }
    if (demoMode) {
      showToast(t('Document attach is available after live sign-in'));
      return;
    }
    if (docLookupBusy) return;
    docLookupBusy = true;
    attachResult = null;
    notifyListeners();
    try {
      docLookup = await _repo.documentLookup(number);
      docAttachments = docLookup!.attachments;
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not look up the document'));
    } finally {
      docLookupBusy = false;
      notifyListeners();
    }
  }

  void _addFile(String path) {
    if (attachFiles.any((f) => f.path == path)) return;
    attachFiles.add((path: path, name: path.split(RegExp(r'[\\/]')).last));
    notifyListeners();
  }

  void removeAttachFile(String path) {
    attachFiles.removeWhere((f) => f.path == path);
    notifyListeners();
  }

  /// Take a single photo (JPEG) and stage it as an image.
  Future<void> attachTakePhoto() async {
    try {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
      if (shot != null) _addFile(shot.path);
    } catch (_) {
      showToast(t('Could not open the camera'));
    }
  }

  /// Pick one or more images from the gallery (Android Photo Picker / iOS).
  Future<void> attachFromGallery() async {
    try {
      final shots = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
      for (final s in shots) {
        _addFile(s.path);
      }
    } catch (_) {
      showToast(t('Could not open the gallery'));
    }
  }

  /// Pick files from device storage / iCloud / Drive (system Files picker).
  Future<void> attachPickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
      if (res == null) return;
      for (final f in res.files) {
        if (f.path != null) _addFile(f.path!);
      }
    } catch (_) {
      showToast(t('Could not open files'));
    }
  }

  /// Advanced document scan: native edge detection + perspective (skew)
  /// correction + colour/brightness enhancement, multi-page → one PDF.
  /// Resolve camera permission for scanning. Returns 'granted', 'denied', or
  /// 'settings' (permanently denied / restricted → the UI should offer to open
  /// app settings). This mirrors what the scanner needs, so the screen can act
  /// on it *before* invoking the native scanner.
  Future<String> ensureCameraPermission() async {
    var s = await Permission.camera.status;
    if (s.isGranted) return 'granted';
    if (s.isPermanentlyDenied || s.isRestricted) return 'settings';
    s = await Permission.camera.request();
    if (s.isGranted) return 'granted';
    if (s.isPermanentlyDenied || s.isRestricted) return 'settings';
    return 'denied';
  }

  Future<void> openAppPermissionSettings() => openAppSettings();

  /// Runs the native document scanner. Camera permission is expected to be
  /// granted already (the screen checks first via [ensureCameraPermission]).
  Future<void> attachScanDocument() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(noOfPages: 20, isGalleryImportAllowed: true);
      if (pages == null || pages.isEmpty) return;
      final pdfPath = await _imagesToPdf(pages, 'scan');
      if (pdfPath != null) _addFile(pdfPath);
    } catch (_) {
      showToast(t('Scanning failed'));
    }
  }

  // ── capture pages → one PDF (take multiple photos, edit, then combine) ──
  /// Image paths captured with the camera for the PDF currently being built.
  /// The user can add, replace or delete any page before combining.
  final List<String> pageShots = [];

  /// Take a photo and append it as a new page.
  Future<void> addPageShot() async {
    try {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
      if (shot != null) {
        pageShots.add(shot.path);
        notifyListeners();
      }
    } catch (_) {
      showToast(t('Could not open the camera'));
    }
  }

  /// Retake the photo at [index], replacing that page in place.
  Future<void> replacePageShot(int index) async {
    if (index < 0 || index >= pageShots.length) return;
    try {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
      if (shot != null) {
        pageShots[index] = shot.path;
        notifyListeners();
      }
    } catch (_) {
      showToast(t('Could not open the camera'));
    }
  }

  void removePageShot(int index) {
    if (index < 0 || index >= pageShots.length) return;
    pageShots.removeAt(index);
    notifyListeners();
  }

  void clearPageShots() {
    if (pageShots.isEmpty) return;
    pageShots.clear();
    notifyListeners();
  }

  /// Combine the captured pages into one multi-page PDF and stage it for upload.
  Future<void> buildPagesPdf() async {
    if (pageShots.isEmpty) {
      showToast(t('Add at least one page'));
      return;
    }
    final pdf = await _imagesToPdf(List.of(pageShots), 'document');
    if (pdf == null) return;
    _addFile(pdf);
    pageShots.clear();
    showToast(t('Pages combined into a PDF'));
    notifyListeners();
  }

  // ── bulk attach: match files to documents by filename ──────────────
  bool docBatchMode = false;
  bool batchBusy = false;
  final List<BatchDoc> batchDocs = [];

  int get batchFoundCount => batchDocs.where((b) => b.status == 'found').length;
  int get batchPending => batchDocs.where((b) => b.status == 'found' || b.status == 'error').length;

  void setBatchMode(bool on) {
    docBatchMode = on;
    if (!on) batchDocs.clear();
    notifyListeners();
  }

  void _addBatch(Iterable<({String path, String name})> files) {
    for (final f in files) {
      if (batchDocs.any((b) => b.path == f.path)) continue;
      // The filename (minus extension) is the candidate document number.
      final number = f.name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
      final d = BatchDoc(f.path, f.name, number);
      batchDocs.add(d);
      recheckBatch(d);
    }
    notifyListeners();
  }

  Future<void> pickBatchFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
      if (res == null) return;
      _addBatch(res.files.where((f) => f.path != null).map((f) => (path: f.path!, name: f.name)));
    } catch (_) {
      showToast(t('Could not open files'));
    }
  }

  Future<void> pickBatchFromGallery() async {
    try {
      final shots = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
      _addBatch(shots.map((s) => (path: s.path, name: s.name)));
    } catch (_) {
      showToast(t('Could not open the gallery'));
    }
  }

  Future<void> recheckBatch(BatchDoc d) async {
    if (d.number.trim().isEmpty) {
      d.status = 'notfound';
      d.lookup = null;
      notifyListeners();
      return;
    }
    d.status = 'checking';
    notifyListeners();
    try {
      d.lookup = await _repo.documentLookup(d.number.trim());
      d.status = d.lookup!.found ? 'found' : 'notfound';
    } catch (_) {
      d.status = 'notfound';
      d.lookup = null;
    }
    notifyListeners();
  }

  void setBatchNumber(BatchDoc d, String number) {
    d.number = number;
    notifyListeners();
  }

  void removeBatch(BatchDoc d) {
    batchDocs.remove(d);
    notifyListeners();
  }

  Future<void> uploadBatchItem(BatchDoc d) async {
    if (!d.found) return;
    d.status = 'uploading';
    d.message = null;
    notifyListeners();
    try {
      final number = d.lookup!.docNumber.isNotEmpty ? d.lookup!.docNumber : d.number.trim();
      final res = await _repo.attachDocuments(number, [d.path]);
      if (res.success && res.attached > 0) {
        d.status = 'uploaded';
      } else {
        d.status = 'error';
        d.message = res.errors.isNotEmpty ? res.errors.first.message : t('Could not attach the files');
      }
    } on ApiException catch (e) {
      d.status = 'error';
      d.message = e.message;
    } catch (_) {
      d.status = 'error';
      d.message = t('Could not attach the files');
    }
    notifyListeners();
  }

  /// Upload every matched (found) file that hasn't been uploaded yet.
  Future<void> uploadAllFound() async {
    if (batchBusy) return;
    batchBusy = true;
    notifyListeners();
    for (final d in batchDocs.where((b) => b.status == 'found').toList()) {
      await uploadBatchItem(d);
    }
    batchBusy = false;
    notifyListeners();
  }

  /// Combine every staged **image** into a single multi-page PDF (replacing the
  /// images with the one PDF). No-op if fewer than one image is staged.
  Future<void> attachCombineToPdf() async {
    final images = attachFiles.where((f) => _isImageName(f.name)).toList();
    if (images.isEmpty) return;
    final pdfPath = await _imagesToPdf(images.map((f) => f.path).toList(), 'document');
    if (pdfPath == null) return;
    for (final img in images) {
      attachFiles.removeWhere((f) => f.path == img.path);
    }
    _addFile(pdfPath);
  }

  bool _isImageName(String name) => RegExp(r'\.(jpe?g|png|gif|webp|heic)$', caseSensitive: false).hasMatch(name);

  bool get attachHasImages => attachFiles.any((f) => _isImageName(f.name));

  /// Renders a list of image files into a single multi-page PDF in the temp
  /// directory; returns its path (or null on failure).
  Future<String?> _imagesToPdf(List<String> imagePaths, String prefix) async {
    try {
      final doc = pw.Document();
      for (final p in imagePaths) {
        final bytes = await File(p).readAsBytes();
        final img = pw.MemoryImage(bytes);
        doc.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
      }
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/${prefix}_$stamp.pdf');
      await file.writeAsBytes(await doc.save(), flush: true);
      return file.path;
    } catch (_) {
      showToast(t('Could not build the PDF'));
      return null;
    }
  }

  /// Upload the staged files against the looked-up document (§2.2).
  Future<void> submitAttachments() async {
    final look = docLookup;
    if (look == null || !look.found) {
      showToast(t('Look up a valid document first'));
      return;
    }
    if (attachFiles.isEmpty) {
      showToast(t('Add at least one file'));
      return;
    }
    if (attachBusy) return;
    attachBusy = true;
    notifyListeners();
    try {
      final res = await _repo.attachDocuments(look.docNumber.isNotEmpty ? look.docNumber : docNumber.trim(),
          attachFiles.map((f) => f.path).toList());
      attachResult = res;
      if (res.attachments != null) docAttachments = res.attachments;
      if (res.success && res.attached > 0) {
        showToast('${res.attached} ${t('file(s) attached')}');
        attachFiles.clear();
      } else if (res.errors.isNotEmpty) {
        showToast(res.errors.first.message);
      }
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not attach the files'));
    } finally {
      attachBusy = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh / resync of the looked-up document's attachments.
  Future<void> reloadAttachments() async {
    final look = docLookup;
    if (look == null || !look.found || docAttachments == null) return;
    try {
      docAttachments = await _repo.documentAttachments(look.docType, look.docId);
      notifyListeners();
    } catch (_) {/* keep the current list */}
  }

  /// Downloads the attachment (with the Bearer token) to a temp file.
  Future<File?> _fetchAttachment(DocAttachment a) async {
    if (attachmentBusyId != null) return null;
    attachmentBusyId = a.id;
    notifyListeners();
    try {
      final res = await _repo.attachmentFile(a);
      final dir = await getTemporaryDirectory();
      final name = a.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(res.bytes, flush: true);
      return file;
    } on ApiException catch (e) {
      showToast(e.message);
      // Deleted by someone else meanwhile → refresh the list.
      if (e.code == 'NOT_FOUND') await reloadAttachments();
    } catch (_) {
      showToast(t('Could not open the file'));
    } finally {
      attachmentBusyId = null;
      notifyListeners();
    }
    return null;
  }

  /// Opens the attachment in the phone's app for its type (image viewer, PDF
  /// app, …); falls back to the share sheet when nothing can open it.
  Future<void> openAttachment(DocAttachment a) async {
    final file = await _fetchAttachment(a);
    if (file == null) return;
    try {
      final res = await OpenFilex.open(file.path, type: a.mime);
      if (res.type == ResultType.done) return;
    } catch (_) {/* fall back to share */}
    await Share.shareXFiles([XFile(file.path, mimeType: a.mime)]);
  }

  Future<void> shareAttachment(DocAttachment a) async {
    final file = await _fetchAttachment(a);
    if (file == null) return;
    try {
      await Share.shareXFiles([XFile(file.path, mimeType: a.mime)], subject: a.fileName);
    } catch (_) {
      showToast(t('Could not share the file'));
    }
  }

  /// Saves the attachment to the phone's Downloads folder (Android).
  Future<void> saveAttachment(DocAttachment a) async {
    final file = await _fetchAttachment(a);
    if (file == null) return;
    if (!Platform.isAndroid) {
      await Share.shareXFiles([XFile(file.path, mimeType: a.mime)]);
      return;
    }
    try {
      await _downloads.invokeMethod<String>(
          'save', {'bytes': await file.readAsBytes(), 'name': a.fileName, 'mime': a.mime});
      showToast('${t('Saved to Downloads')} · ${a.fileName}');
    } on PlatformException catch (_) {
      showToast(t('Could not save the file'));
    }
  }

  /// Deletes an attachment after the user confirms. Removes the file for the
  /// web too and cannot be undone.
  Future<void> deleteAttachment(DocAttachment a) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || attachmentBusyId != null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(t('Delete attachment?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          '${a.fileName}\n\n${t('The file is removed for everyone, including the web app. This cannot be undone.')}',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(t('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t('Delete'), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    attachmentBusyId = a.id;
    notifyListeners();
    try {
      docAttachments = await _repo.deleteAttachment(a.id);
      showToast(t('Attachment deleted'));
    } on ApiException catch (e) {
      showToast(e.message);
      if (e.code == 'NOT_FOUND') await reloadAttachments();
    } catch (_) {
      showToast(t('Could not delete the attachment'));
    } finally {
      attachmentBusyId = null;
      notifyListeners();
    }
  }

  // ── print labels (v1.4.7) ──────────────────────────────────────────
  List<LabelTemplate> labelTemplates = [];
  int labelTemplateId = 0;
  final Map<int, int> labelQty = {}; // itemId → copies
  bool labelsBusy = false;
  String labelQuery = '';
  // Server empty-state message shown when no label designs exist.
  String? labelEmptyMessage;

  LabelTemplate? get labelTemplate =>
      labelTemplates.where((t) => t.id == labelTemplateId).firstOrNull;

  int get labelTotalCopies => labelQty.values.fold(0, (a, b) => a + b);

  List<Product> get labelProductRows {
    final q = labelQuery.trim().toLowerCase();
    final all = products;
    if (q.isEmpty) return all;
    return all
        .where((p) => p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q) || p.barcode.contains(q))
        .toList();
  }

  void openLabels() {
    nav(Screen.labels);
    loadLabelTemplates();
  }

  void setLabelQuery(String v) {
    labelQuery = v;
    notifyListeners();
  }

  void setLabelTemplate(int id) {
    labelTemplateId = id;
    notifyListeners();
  }

  void setLabelQty(int itemId, int qty) {
    if (qty <= 0) {
      labelQty.remove(itemId);
    } else {
      labelQty[itemId] = qty;
    }
    notifyListeners();
  }

  Future<void> loadLabelTemplates() async {
    if (demoMode) {
      labelTemplates = const [
        LabelTemplate(id: 1, name: 'Shelf 50×30', widthMm: 50, heightMm: 30),
        LabelTemplate(id: 2, name: 'Barcode 40×20', widthMm: 40, heightMm: 20),
      ];
      labelTemplateId = labelTemplates.first.id;
      labelEmptyMessage = null;
      notifyListeners();
      return;
    }
    try {
      final res = await _repo.labelTemplates();
      labelTemplates = res.templates;
      labelEmptyMessage = res.message;
      if (labelTemplateId == 0 && labelTemplates.isNotEmpty) labelTemplateId = labelTemplates.first.id;
    } catch (_) {
      showToast(t('Could not load label templates'));
    }
    notifyListeners();
  }

  Future<void> printLabels() async {
    if (demoMode) {
      showToast(t('Label printing is available after live sign-in'));
      return;
    }
    if (labelTemplateId == 0) {
      showToast(t('Choose a label template first'));
      return;
    }
    if (labelQty.isEmpty) {
      showToast(t('Add items to print first'));
      return;
    }
    if (labelsBusy) return;
    labelsBusy = true;
    notifyListeners();
    try {
      final items = labelQty.entries.map((e) => (itemId: e.key, quantity: e.value)).toList();
      final res = await _repo.printLabels(templateId: labelTemplateId, items: items);
      final pdf = _validatePdf(res);
      if (pdf == null) return;
      await _deliverPdf(pdf.bytes, pdf.filename);
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not generate the labels PDF'));
    } finally {
      labelsBusy = false;
      notifyListeners();
    }
  }

  // ── suppliers ──────────────────────────────────────────────────────
  String supplierQuery = '';
  int supplierId = 0;

  void goSuppliers() {
    nav(Screen.suppliers);
    supplierList.ensureLoaded();
  }

  void setSupplierQuery(String v) {
    supplierQuery = v;
    supplierList.setSearch(v);
  }

  Customer? get supplier => suppliers.where((s) => s.id == supplierId).firstOrNull;

  void openSupplierStatement(int id) {
    supplierId = id;
    _statement = null;
    statementAsOn = null;
    statementParty = 'supplier';
    statementReturn = Screen.suppliers;
    nav(Screen.statement);
    if (!demoMode) _loadStatement(id);
  }

  // ── reports ────────────────────────────────────────────────────────
  ({String from, String to}) _reportRangeDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fmt = DateFormat('yyyy-MM-dd');
    late DateTime from;
    switch (reportRange) {
      case 'today':
        from = today;
        break;
      case '30d':
        from = today.subtract(const Duration(days: 29));
        break;
      case 'custom':
        from = DateTime(now.year, 1, 1);
        break;
      case '7d':
      default:
        from = today.subtract(const Duration(days: 6));
    }
    return (from: fmt.format(from), to: fmt.format(today));
  }

  void goReports() {
    nav(Screen.reports);
    if (!demoMode) _loadReports();
  }

  Future<void> _loadReports() async {
    reportsLoading = true;
    notifyListeners();
    final r = _reportRangeDates();
    try {
      final results = await Future.wait([
        _repo.salesReport(from: r.from, to: r.to).catchError((_) => const ReportData()),
        _repo.purchaseReport(from: r.from, to: r.to).catchError((_) => const ReportData()),
      ]);
      salesRep = results[0];
      purchaseRep = results[1];
    } catch (_) {
      salesRep = const ReportData();
      purchaseRep = const ReportData();
    }
    reportsLoading = false;
    notifyListeners();
  }

  // statement
  Screen statementReturn = Screen.customer; // where the statement back-button returns
  String statementParty = 'customer'; // customer | supplier
  String statementQuery = '';

  /// Display name for the current statement's party.
  String get statementPartyName =>
      statementParty == 'supplier' ? (supplier?.name ?? 'Supplier') : customer.name;

  void openStatementPicker() {
    statementReturn = Screen.statementPicker;
    nav(Screen.statementPicker);
    statementList.ensureLoaded();
  }

  void setStatementQuery(String v) {
    statementQuery = v;
    statementList.setSearch(v);
  }

  /// Chosen from the picker → load that customer's statement.
  void openStatementFor(int id) {
    cid = id;
    _statement = null;
    statementAsOn = null;
    statementParty = 'customer';
    statementReturn = Screen.statementPicker;
    nav(Screen.statement);
    if (!demoMode) _loadStatement(id);
  }

  /// Opened from Customer 360 (customer already selected).
  void goStatement() {
    _statement = null;
    statementAsOn = null;
    statementParty = 'customer';
    statementReturn = Screen.customer;
    nav(Screen.statement);
    if (!demoMode) _loadStatement(cid);
  }

  void setStatementAsOn(DateTime date) {
    statementAsOn = date;
    notifyListeners();
    if (!demoMode) _loadStatement(statementParty == 'supplier' ? supplierId : cid);
  }

  Future<void> _loadStatement(int id) async {
    statementLoading = true;
    notifyListeners();
    try {
      final asOn = statementAsOn == null ? null : DateFormat('yyyy-MM-dd').format(statementAsOn!);
      _statement = statementParty == 'supplier'
          ? await _repo.supplierStatement(id, asOn: asOn)
          : await _repo.customerStatement(id, asOn: asOn);
    } catch (_) {
      _statement = const StatementResult(rows: []);
    }
    statementLoading = false;
    notifyListeners();
  }

  // reports
  void pickRange(String r) {
    reportRange = r;
    notifyListeners();
    if (!demoMode) _loadReports();
  }

  // settings
  void pickLang(String l) {
    if (l != 'en' && l != 'ar') return;
    lang = l;
    _store.setLang(l);
    notifyListeners();
  }

  /// Text direction for the active language (Arabic is right-to-left).
  bool get isRtl => lang == 'ar';

  void pickLight() {
    isDark = false;
    notifyListeners();
  }

  void pickDark() {
    isDark = true;
    notifyListeners();
  }

  void toggleBio() {
    biometrics = !biometrics;
    notifyListeners();
    _store.setBioEnabled(biometrics);
    if (biometrics && !biometricAvailable) {
      showToast(t('No fingerprint enrolled on this device'));
    }
  }

  void toggleOffline() {
    offline = !offline;
    notifyListeners();
  }

  void pickRole(Role r) {
    role = r;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    super.dispose();
  }
}

/// "Hide zero balances" / "Sort by balance" for a customer or supplier list.
class PartyFilter {
  bool hideZero = false;
  bool byBalance = false;
}
