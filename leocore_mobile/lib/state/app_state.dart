import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
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
import '../models/models.dart';
import '../models/reports.dart';
import '../utils/money.dart';

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
class AppState extends ChangeNotifier {
  AppState() {
    _restoreSession();
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
  Set<String> _menuKeys = {};
  List<String> _liveCategories = [];

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
  Map<int, int> counts = {1: 118, 3: 96, 5: 19, 6: 8};

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

  List<Product> get filteredProducts {
    final q = query.trim().toLowerCase();
    return products.where((p) {
      final catOk = cat == 'All' || p.cat == cat;
      final qOk = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          p.barcode.contains(q);
      return catOk && qOk;
    }).toList();
  }

  List<Product> get lowRows => products.where((p) => p.stock > kUnknownStock && p.stock <= 25).toList();

  // ── customers search ───────────────────────────────────────────────
  String customerQuery = '';
  List<Customer> get customerSearchRows {
    final q = customerQuery.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.area.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  void setCustomerQuery(String v) {
    customerQuery = v;
    notifyListeners();
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
  List<Product> get countProducts => MockData.expected.keys.map(MockData.byId).toList();
  int countExpected(int id) => MockData.expected[id] ?? 0;
  int countValue(int id) => counts[id] ?? 0;
  int get countVar => countProducts.where((p) => countValue(p.id) != countExpected(p.id)).length;

  double get subtotal => cart.fold(0, (a, l) => a + productById(l.pid).price * l.qty);
  double get vat => subtotal * 0.10;
  double get total => subtotal + vat;

  /// Quotation line totals (same 10% VAT basis as the cash sale preview).
  /// These are indicative only — the server prices the document on save.
  double get quoteSubtotal => quoteLines.fold(0, (a, l) => a + productById(l.pid).price * l.qty);
  double get quoteVat => quoteSubtotal * 0.10;
  double get quoteTotal => quoteSubtotal + quoteVat;

  // Barcode scan result
  Product? scanned;
  bool scanLoading = false;

  // ══════════════════════════════════════════════════════════════════
  //  Permissions (menu-driven in live mode, role-driven in demo)
  // ══════════════════════════════════════════════════════════════════
  bool _menuHas(String needle) => _menuKeys.any((k) => k.contains(needle));

  bool get mSuppliers => demoMode ? role == Role.manager : (_menuKeys.isEmpty || _menuHas('supplier'));
  bool get mReports => demoMode ? role == Role.manager : (_menuKeys.isEmpty || _menuHas('report'));

  /// Manager reports (v1.4.5+) split by RBAC gate.
  /// `MobileReports` → analytics; `MobileFinanceReports` → money/profit/cost.
  bool get mAnalytics => demoMode ? role == Role.manager : _menuHas('report');
  bool get mFinance => demoMode ? role == Role.manager : (_menuHas('finance') || _menuHas('financ'));

  /// Print Labels (v1.4.7) — gate: `MobileLabels`.
  bool get mLabels => demoMode ? role != Role.salesRep : _menuHas('label');

  /// Attach Docs (1.6.x) — gate: `MobileDocuments` (menu id `documents`).
  bool get mDocuments => demoMode ? role != Role.salesRep : _menuHas('document');
  bool get mCount => demoMode
      ? role != Role.salesRep
      : (_menuKeys.isEmpty || _menuHas('count') || _menuHas('stock'));
  bool get mSale => demoMode
      ? role != Role.storekeeper
      : (_menuKeys.isEmpty || _menuHas('sale') || _menuHas('invoice') || _menuHas('cash'));

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
    dataLoading = true;
    dataError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.products(pageSize: 200),
        _repo.customers(pageSize: 200),
        _repo.kpis().catchError((_) => const KpiData()),
        _repo.menuKeys().catchError((_) => <String>[]),
        _repo.categories().catchError((_) => <String>[]),
        _repo.warehouses().catchError((_) => <({int id, String code, String name})>[]),
      ]);
      _products = results[0] as List<Product>;
      _customers = results[1] as List<Customer>;
      kpis = results[2] as KpiData;
      _menuKeys = (results[3] as List<String>).toSet();
      _liveCategories = results[4] as List<String>;
      _warehouses = results[5] as List<({int id, String code, String name})>;
      if (_warehouses.isNotEmpty) {
        warehouseId = _warehouses.first.id;
        wh = _warehouses.first.name;
      }
      // Real 7-day trend for the Home chart.
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
      if (_products!.isNotEmpty) pid = _products!.first.id;
      if (_customers!.isNotEmpty) cid = _customers!.first.id;
    } on ApiException catch (e) {
      dataError = e.message;
    } catch (_) {
      dataError = 'Could not load data from the server.';
    }
    dataLoading = false;
    notifyListeners();
  }

  Future<void> retryLoad() => _loadAll();

  // ══════════════════════════════════════════════════════════════════
  //  Actions
  // ══════════════════════════════════════════════════════════════════
  void nav(Screen s) {
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
        nav(Screen.home);
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
      case Screen.invoice:
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
    _menuKeys = {};
    nav(Screen.login);
  }

  // products
  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void pickCat(String c) {
    cat = c;
    notifyListeners();
  }

  void clearSearch() {
    query = '';
    cat = 'All';
    notifyListeners();
  }

  Future<void> doRefresh() async {
    refreshing = true;
    notifyListeners();
    if (!demoMode) {
      try {
        _products = await _repo.products(search: query, pageSize: 200);
      } catch (_) {}
    } else {
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    refreshing = false;
    notifyListeners();
  }

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

  /// Writes the PDF to the documents directory (so it persists as a real
  /// downloaded file) and opens it in the device's PDF viewer. Falls back to
  /// the share sheet when no viewer is installed.
  Future<void> _deliverPdf(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    lastPdfPath = file.path;
    // The file is already saved. Try to open it in a PDF viewer.
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
  Future<void> _promptNoPdfViewer(String path, String filename, {required bool noViewer}) async {
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
          noViewer
              ? t('This phone has no app to open PDF files. Install a free PDF viewer to open statements and documents, or share this file to another app.')
              : t('Could not open the PDF here. Install a PDF viewer, or share this file to another app.'),
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
      showToast('${t('Saved')} · $filename');
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

  Future<void> shareStmt() async {
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${pdf.filename}');
      await file.writeAsBytes(pdf.bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: pdf.filename)],
        subject: 'Account statement — $statementPartyName',
      );
    } on ApiException catch (e) {
      showToast(e.message);
    } catch (_) {
      showToast(t('Could not generate the statement PDF'));
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

  /// Absolute URL for a server-relative image path.
  String imageUrl(String relative) {
    if (relative.isEmpty) return relative;
    if (relative.startsWith('http')) return relative;
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

  void countScanned() {
    countSubmitted = false;
    scanFound = false;
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
    countStarted = true;
    countSubmitted = false;
    notifyListeners();
  }

  void incCount(int id) {
    counts[id] = countValue(id) + 1;
    notifyListeners();
  }

  void decCount(int id) {
    counts[id] = (countValue(id) - 1).clamp(0, 1 << 31);
    notifyListeners();
  }

  void submitCount() {
    countSubmitted = true;
    showToast(t('Count session submitted'));
  }

  void closeCountDone() {
    countStarted = false;
    countSubmitted = false;
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
        lines: [for (final l in cart) (itemId: l.pid, qty: l.qty)],
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
        lines: [for (final l in quoteLines) (itemId: l.pid, qty: l.qty)],
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

  void openAttachDocs() {
    docNumber = '';
    docLookup = null;
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
    if (docLookup != null) docLookup = null;
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

  List<Customer> get supplierRows {
    final q = supplierQuery.trim().toLowerCase();
    if (q.isEmpty) return suppliers;
    return suppliers.where((s) => s.name.toLowerCase().contains(q) || s.area.toLowerCase().contains(q)).toList();
  }

  void goSuppliers() {
    supplierQuery = '';
    nav(Screen.suppliers);
    if (!demoMode && _suppliers == null) _loadSuppliers();
  }

  void setSupplierQuery(String v) {
    supplierQuery = v;
    notifyListeners();
  }

  Future<void> _loadSuppliers() async {
    suppliersLoading = true;
    notifyListeners();
    try {
      _suppliers = await _repo.suppliers(pageSize: 200);
    } catch (_) {
      _suppliers = [];
    }
    suppliersLoading = false;
    notifyListeners();
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

  /// Filtered customer list for the statement picker (type-to-search).
  List<Customer> get statementPickerRows {
    final q = statementQuery.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers.where((c) => c.name.toLowerCase().contains(q) || c.area.toLowerCase().contains(q)).toList();
  }

  void openStatementPicker() {
    statementQuery = '';
    statementReturn = Screen.statementPicker;
    nav(Screen.statementPicker);
  }

  void setStatementQuery(String v) {
    statementQuery = v;
    notifyListeners();
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
    _toastTimer?.cancel();
    super.dispose();
  }
}
