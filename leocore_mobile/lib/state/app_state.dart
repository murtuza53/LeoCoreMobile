import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/biometrics.dart';
import '../api/repositories.dart';
import '../api/secure_store.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
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
  receipt,
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

StockLevel stockLevelOf(int stock) => stock == 0
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

  // ── networking ─────────────────────────────────────────────────────
  final SecureStore _store = SecureStore();
  final Biometrics _bio = Biometrics();
  late final ApiClient api = ApiClient(_store)..onSessionExpired = _onSessionExpired;
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

  // ── navigation ─────────────────────────────────────────────────────
  Screen screen = Screen.login;

  // ── login ──────────────────────────────────────────────────────────
  String loginUser = 'yousif.m';
  String loginPass = '';
  bool loginErr = false;
  bool keep = true;
  String serverUrl = 'https://leocoredemo.seksolution.com';

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

  // ── cart / invoice ─────────────────────────────────────────────────
  List<CartLine> cart = []; // a cash sale starts empty
  // Multi-tender payments: each line is a method + amount.
  List<({String method, double amount})> payments = [];
  String payMethod = 'Cash';
  String payAmount = '';

  static const paymentMethods = ['Cash', 'Card / Benefit', 'Bank Transfer'];

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

  List<Product> get lowRows => products.where((p) => p.stock >= 0 && p.stock <= 25).toList();

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
  double get totalPaid => payments.fold(0.0, (a, p) => a + p.amount);
  double get balanceDue {
    final b = total - totalPaid;
    return b > 0 ? b : 0;
  }

  double get change {
    final c = totalPaid - total;
    return c > 0 ? c : 0;
  }

  // Barcode scan result
  Product? scanned;
  bool scanLoading = false;

  // ══════════════════════════════════════════════════════════════════
  //  Permissions (menu-driven in live mode, role-driven in demo)
  // ══════════════════════════════════════════════════════════════════
  bool _menuHas(String needle) => _menuKeys.any((k) => k.contains(needle));

  bool get mSuppliers => demoMode ? role == Role.manager : (_menuKeys.isEmpty || _menuHas('supplier'));
  bool get mReports => demoMode ? role == Role.manager : (_menuKeys.isEmpty || _menuHas('report'));
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
    final s = await _store.serverUrl;
    if (s != null && s.isNotEmpty) serverUrl = s;
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
    // Refresh failed — drop to the login screen.
    demoMode = true;
    _products = null;
    _customers = null;
    kpis = null;
    screen = Screen.login;
    loginErr = false;
    loginErrMsg = 'Your session expired. Please sign in again.';
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
        nav(Screen.invoice);
        return true;
      case Screen.settings:
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
    showToast('Press back again to exit');
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
      notifyListeners();
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
        showToast('No fingerprint enrolled on this device');
        return;
      }
    }
    final access = await _store.accessToken;
    final refresh = await _store.refreshToken;
    if (access == null || refresh == null || access.isEmpty) {
      showToast('Sign in with your password first');
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
          _productDetail!.stock < 0) {
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
        showToast('Product updated');
      } on ApiException catch (e) {
        showToast(e.message);
      } catch (_) {
        showToast('Could not update product');
      }
    } else {
      showToast('Product updated');
    }
  }

  // cart
  void addToCart(int pid, [String? note]) {
    final existing = cart.where((l) => l.pid == pid).toList();
    if (existing.isNotEmpty) {
      existing.first.qty += 1;
    } else {
      cart.add(CartLine(pid, 1));
    }
    showToast(note ?? 'Added to memo');
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
    showToast('Filters applied');
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
      showToast('No phone number on file');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (!await launchUrl(uri)) showToast('Could not open the dialer');
  }

  Future<void> waCust() async {
    final digits = customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      showToast('No phone number on file');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showToast('WhatsApp is not installed');
    }
  }

  Future<void> navCust() async {
    final q = Uri.encodeComponent(
        [customer.name, customer.area].where((s) => s.isNotEmpty).join(', '));
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showToast('Could not open Maps');
    }
  }

  // ── statement PDF (download → share / print) ───────────────────────
  /// True while the statement PDF is being fetched from the server, so the
  /// Share / Print buttons can show an inline spinner.
  bool statementSharing = false; // busy while sharing
  bool statementPrinting = false; // busy while printing

  bool get statementBusy => statementSharing || statementPrinting;

  /// Downloads the statement PDF and returns validated bytes + a safe
  /// filename, or `null` if it isn't a real PDF (with a toast explaining why).
  /// Shared by [shareStmt] and [printStmt].
  Future<({Uint8List bytes, String filename})?> _fetchStatementPdf() async {
    final id = statementParty == 'supplier' ? supplierId : cid;
    final asOn = statementAsOn == null ? null : DateFormat('yyyy-MM-dd').format(statementAsOn!);
    final res = await _repo.statementPdf(statementParty, id, asOn: asOn);
    if (res.bytes.isEmpty) {
      showToast('The statement came back empty');
      return null;
    }
    // Guard: the server must actually return a PDF. If PDF export isn't
    // enabled it returns JSON — don't hand the user a broken .pdf.
    final isPdf = res.contentType.toLowerCase().contains('pdf') ||
        (res.bytes.length >= 4 &&
            res.bytes[0] == 0x25 && res.bytes[1] == 0x50 &&
            res.bytes[2] == 0x44 && res.bytes[3] == 0x46); // %PDF
    if (!isPdf) {
      showToast('PDF export is not enabled on your server yet');
      return null;
    }
    final safe = res.filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return (bytes: Uint8List.fromList(res.bytes), filename: safe);
  }

  Future<void> shareStmt() async {
    if (demoMode) {
      showToast('Statement PDF is available after live sign-in');
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
      showToast('Could not generate the statement PDF');
    } finally {
      statementSharing = false;
      notifyListeners();
    }
  }

  /// Hands the downloaded PDF to the phone's print framework, where the user
  /// can pick a printer (or "Save as PDF").
  Future<void> printStmt() async {
    if (demoMode) {
      showToast('Statement PDF is available after live sign-in');
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
      showToast('Could not open the print dialog');
    } finally {
      statementPrinting = false;
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
      showToast('Could not open the store');
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
      showToast('Update could not be started');
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
      showToast(e.status == 404 ? 'No product matches "$trimmed"' : e.message);
      notifyListeners();
      return;
    } catch (_) {
      found = null;
      scanLoading = false;
      showToast('No product matches "$trimmed"');
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
    showToast('Count session submitted');
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

  // invoice / receipt — multi-tender payments
  void setPayMethod(String m) {
    payMethod = m;
    notifyListeners();
  }

  void setPayAmount(String v) {
    payAmount = v;
    notifyListeners();
  }

  /// Add the entered amount under the selected method as a new payment line.
  void addPayment() {
    final amt = double.tryParse(payAmount.trim().replaceAll(',', ''));
    if (amt == null || amt <= 0) {
      showToast('Enter a payment amount');
      return;
    }
    payments = [...payments, (method: payMethod, amount: amt)];
    payAmount = '';
    notifyListeners();
  }

  /// Quick "pay the remaining balance" with the selected method.
  void payRemaining() {
    if (balanceDue <= 0) return;
    payments = [...payments, (method: payMethod, amount: balanceDue)];
    notifyListeners();
  }

  void removePayment(int index) {
    final p = [...payments];
    if (index >= 0 && index < p.length) {
      p.removeAt(index);
      payments = p;
      notifyListeners();
    }
  }

  void completeSale() {
    if (cart.isEmpty) {
      showToast('Add items to the memo first');
      return;
    }
    nav(Screen.receipt);
    _maybeAskReview();
  }

  void newSale() {
    cart = [];
    payments = [];
    payAmount = '';
    nav(Screen.invoice);
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
    lang = l;
    notifyListeners();
    if (l == 'ar') {
      showToast('Arabic RTL sample — full mirroring in a later build');
    }
  }

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
      showToast('No fingerprint enrolled on this device');
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
