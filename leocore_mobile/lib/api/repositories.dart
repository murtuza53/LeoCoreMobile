import 'package:intl/intl.dart';

import '../models/models.dart';
import 'api_client.dart';

// ── JSON helpers ─────────────────────────────────────────────────────────
dynamic _pick(Map j, List<String> keys) {
  for (final k in keys) {
    if (j.containsKey(k) && j[k] != null) return j[k];
    for (final e in j.entries) {
      if (e.key.toString().toLowerCase() == k.toLowerCase() && e.value != null) {
        return e.value;
      }
    }
  }
  return null;
}

String _s(Map j, List<String> keys, [String def = '']) {
  final v = _pick(j, keys);
  return v == null ? def : v.toString();
}

double _d(Map j, List<String> keys, [double def = 0]) {
  final v = _pick(j, keys);
  if (v == null) return def;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? def;
}

int _i(Map j, List<String> keys, [int def = 0]) => _d(j, keys, def.toDouble()).round();

final DateFormat _dfOut = DateFormat('dd MMM yyyy');

/// Formats an ISO 8601 date/date-time into the app's `dd MMM yyyy`.
String _fmtDate(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return _dfOut.format(dt.toLocal());
}

/// Home KPIs. Live fields come from `KpisResponse.kpis`; the ones the API
/// doesn't expose (collections, outstanding AR, low-stock) stay null so the UI
/// shows "—" in live mode.
class KpiData {
  final double? salesToday;
  final double? salesThisMonth;
  final double? purchasesThisMonth;
  final double? collections;
  final double? outstandingAr;
  final int? lowStock;
  final int? customers;
  final int? suppliers;
  final int? items;
  const KpiData({
    this.salesToday,
    this.salesThisMonth,
    this.purchasesThisMonth,
    this.collections,
    this.outstandingAr,
    this.lowStock,
    this.customers,
    this.suppliers,
    this.items,
  });

  factory KpiData.fromJson(Map j) {
    final k = _pick(j, ['kpis']);
    final m = k is Map ? k : j;
    double? nd(List<String> keys) => _pick(m, keys) == null ? null : _d(m, keys);
    int? ni(List<String> keys) => _pick(m, keys) == null ? null : _i(m, keys);
    return KpiData(
      salesToday: nd(['salesToday']),
      salesThisMonth: nd(['salesThisMonth']),
      purchasesThisMonth: nd(['purchasesThisMonth']),
      collections: nd(['collections']),
      outstandingAr: nd(['outstandingAr']),
      lowStock: ni(['lowStock']),
      customers: ni(['customers']),
      suppliers: ni(['suppliers']),
      items: ni(['items']),
    );
  }
}

/// A low-stock / dead-stock row (`StockRow`).
class StockRowData {
  final int id;
  final String code;
  final String name;
  final String barcode;
  final int onHand;
  final int daysIdle;
  const StockRowData({
    required this.id,
    required this.code,
    required this.name,
    required this.barcode,
    required this.onHand,
    this.daysIdle = 0,
  });
}

/// Sales / purchase report (`SalesReport` / `PurchaseReport`).
class ReportData {
  final double total;
  final List<({String name, double total})> top; // top customers / suppliers
  final List<({String label, double total})> trend; // daily trend
  const ReportData({this.total = 0, this.top = const [], this.trend = const []});
}

/// Statement result mapped from `StatementResponse`.
class StatementResult {
  final List<StmtRow> rows;
  final double opening;
  final double closing;
  final List<double> aging; // [0–30, 31–60, 61–90, 90+]
  const StatementResult({
    required this.rows,
    this.opening = 0,
    this.closing = 0,
    this.aging = const [0, 0, 0, 0],
  });
}

/// A created sales document (cash-invoice draft or quotation).
///
/// The server prices the lines and assigns the number, so every total here
/// comes back from it rather than being computed on the device.
class SalesDocResult {
  final int id;
  final String number;
  final String status; // "Draft" for cash invoices, "Open" for quotations
  final String date;
  final String expiryDate; // quotations only
  final double subTotal;
  final double discount;
  final double vatAmount;
  final double grandTotal;
  const SalesDocResult({
    required this.id,
    required this.number,
    this.status = '',
    this.date = '',
    this.expiryDate = '',
    this.subTotal = 0,
    this.discount = 0,
    this.vatAmount = 0,
    this.grandTotal = 0,
  });

  factory SalesDocResult.fromJson(Map j) => SalesDocResult(
        id: _i(j, ['id']),
        number: _s(j, ['number']),
        status: _s(j, ['status']),
        date: _fmtDate(_s(j, ['date'])),
        expiryDate: _fmtDate(_s(j, ['expiryDate'])),
        subTotal: _d(j, ['subTotal']),
        discount: _d(j, ['discount']),
        vatAmount: _d(j, ['vatAmount']),
        grandTotal: _d(j, ['grandTotal']),
      );
}

/// Repository over the read + item-master endpoints.
class LeoRepository {
  LeoRepository(this._client);
  final ApiClient _client;

  // ── Products ───────────────────────────────────────────────────────────
  Future<List<Product>> products({String? search, int page = 1, int pageSize = 100}) async {
    final list = await _client.getList('/products', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return list.whereType<Map>().map((m) => mapProduct(m, fromList: true)).toList();
  }

  Future<Product> product(int id) async {
    final j = await _client.getJson('/products/$id');
    return mapProduct(j);
  }

  Future<Product> productByBarcode(String code) async {
    final j = await _client.getJson('/products/by-barcode/$code');
    return mapProduct(j);
  }

  Future<List<String>> categories() async {
    final list = await _client.getList('/categories');
    return list.whereType<Map>().map((m) => _s(m, ['name'])).where((s) => s.isNotEmpty).toList();
  }

  // ── Customers / suppliers ──────────────────────────────────────────────
  Future<List<Customer>> customers({String? search, int page = 1, int pageSize = 100}) async {
    final list = await _client.getList('/customers', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return list.whereType<Map>().map(mapParty).toList();
  }

  Future<List<Customer>> suppliers({String? search, int page = 1, int pageSize = 100}) async {
    final list = await _client.getList('/suppliers', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return list.whereType<Map>().map(mapParty).toList();
  }

  // ── Statement / ledger / KPIs ──────────────────────────────────────────
  Future<StatementResult> customerStatement(int id, {String? asOn}) async {
    final j = await _client.getJson('/customers/$id/statement', query: {if (asOn != null) 'asOn': asOn});
    return mapStatement(j);
  }

  Future<StatementResult> supplierStatement(int id, {String? asOn}) async {
    final j = await _client.getJson('/suppliers/$id/statement', query: {if (asOn != null) 'asOn': asOn});
    return mapStatement(j);
  }

  /// Streams the statement as a PDF (party = 'customer' | 'supplier').
  Future<({List<int> bytes, String filename, String contentType})> statementPdf(
    String party,
    int id, {
    String? asOn,
  }) {
    final seg = party == 'supplier' ? 'suppliers' : 'customers';
    return _client.downloadBytes(
      '/$seg/$id/statement',
      query: {'format': 'pdf', if (asOn != null) 'asOn': asOn},
      fallbackName: 'statement_$id.pdf',
    );
  }

  // ── Sales documents (cash-invoice draft & quotations) ──────────────────
  /// Result of creating a sales document.
  ///
  /// The server prices the lines, so the totals come back from it.
  Future<SalesDocResult> createCashInvoiceDraft({
    required int warehouseId,
    int? customerId,
    required List<({int itemId, int qty})> lines,
    required String idempotencyKey,
  }) async {
    final j = await _client.postJson(
      '/sales/cash-invoice/draft',
      idempotencyKey: idempotencyKey,
      body: {
        'warehouseId': warehouseId,
        if (customerId != null) 'customerId': customerId,
        'lines': [for (final l in lines) {'itemId': l.itemId, 'qty': l.qty}],
      },
    );
    return SalesDocResult.fromJson(j);
  }

  Future<SalesDocResult> createQuotation({
    required int customerId,
    required List<({int itemId, int qty})> lines,
    required String idempotencyKey,
  }) async {
    final j = await _client.postJson(
      '/sales/quotations',
      idempotencyKey: idempotencyKey,
      body: {
        'customerId': customerId,
        'lines': [for (final l in lines) {'itemId': l.itemId, 'qty': l.qty}],
      },
    );
    return SalesDocResult.fromJson(j);
  }

  Future<({List<int> bytes, String filename, String contentType})> quotationPdf(int id) {
    return _client.downloadBytes('/sales/quotations/$id/pdf', fallbackName: 'quotation_$id.pdf');
  }

  // ── Product photos ─────────────────────────────────────────────────────
  /// Uploads a photo for [productId] as multipart (field name `images`) and
  /// returns the product's images as the server now holds them.
  Future<List<ProductImage>> uploadProductImage(int productId, String filePath) async {
    final j = await _client.postMultipart(
      '/products/$productId/images',
      field: 'images',
      filePaths: [filePath],
    );
    return mapProductImages(j['images']);
  }

  Future<void> deleteProductImage(int productId, int imageId) =>
      _client.deleteNoContent('/products/$productId/images/$imageId');

  static List<ProductImage> mapProductImages(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      return ProductImage(
        id: _i(m, ['id']),
        url: _s(m, ['url']),
        isPrimary: _pick(m, ['isPrimary']) == true,
      );
    }).where((i) => i.url.isNotEmpty).toList();
  }

  // ── Reports ────────────────────────────────────────────────────────────
  Future<ReportData> salesReport({required String from, required String to}) async {
    final j = await _client.getJson('/reports/sales', query: {'from': from, 'to': to});
    return _mapReport(j, 'topCustomers', 'totalSales');
  }

  Future<ReportData> purchaseReport({required String from, required String to}) async {
    final j = await _client.getJson('/reports/purchase', query: {'from': from, 'to': to});
    return _mapReport(j, 'topSuppliers', 'totalPurchases');
  }

  static ReportData _mapReport(Map j, String topKey, String totalKey) {
    final data = _pick(j, ['data']);
    final m = data is Map ? data : j;
    final topRaw = _pick(m, [topKey]);
    final trendRaw = _pick(m, ['dailyTrend']);
    final top = <({String name, double total})>[];
    if (topRaw is List) {
      for (final t in topRaw.whereType<Map>()) {
        top.add((name: _s(t, ['name'], '—'), total: _d(t, ['total'])));
      }
    }
    final trend = <({String label, double total})>[];
    if (trendRaw is List) {
      for (final t in trendRaw.whereType<Map>()) {
        trend.add((label: _s(t, ['date']), total: _d(t, ['total'])));
      }
    }
    return ReportData(total: _d(m, [totalKey]), top: top, trend: trend);
  }

  Future<List<LedgerEntry>> stockLedger({required int itemId, int? warehouseId}) async {
    final list = await _client.getList('/inventory/stock-ledger', query: {
      'itemId': itemId,
      if (warehouseId != null) 'warehouseId': warehouseId,
      'page': 1,
      'pageSize': 50,
    });
    return list.whereType<Map>().map(mapLedger).toList();
  }

  Future<KpiData> kpis() async {
    final j = await _client.getJson('/dashboard/kpis');
    return KpiData.fromJson(j);
  }

  Future<List<({int id, String code, String name})>> warehouses() async {
    final list = await _client.getList('/warehouses');
    return list
        .whereType<Map>()
        .map((m) => (id: _i(m, ['id']), code: _s(m, ['code']), name: _s(m, ['name'], 'Warehouse')))
        .toList();
  }

  Future<List<StockRowData>> lowStock() async {
    final list = await _client.getList('/inventory/low-stock', query: {'page': 1, 'pageSize': 100});
    return list.whereType<Map>().map(_mapStockRow).toList();
  }

  Future<List<StockRowData>> deadStock({int days = 90}) async {
    final list = await _client.getList('/inventory/dead-stock', query: {'days': days, 'page': 1, 'pageSize': 100});
    return list.whereType<Map>().map(_mapStockRow).toList();
  }

  static StockRowData _mapStockRow(Map j) => StockRowData(
        id: _i(j, ['id']),
        code: _s(j, ['code']),
        name: _s(j, ['name'], 'Unnamed'),
        barcode: _s(j, ['barcode']),
        onHand: _i(j, ['onHand']),
        daysIdle: _i(j, ['daysIdle']),
      );

  // ── Menu (permission-filtered) ─────────────────────────────────────────
  Future<List<String>> menuKeys() async {
    final j = await _client.getJson('/menu');
    final items = j['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => '${_s(m, ['id'])} ${_s(m, ['route'])} ${_s(m, ['title'])}'.toLowerCase())
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Future<void> updateProduct(int id, {String? barcode, String? model, double? defaultPrice}) async {
    final body = {
      if (barcode != null) 'barcode': barcode,
      if (model != null) 'model': model,
      if (defaultPrice != null) 'defaultPrice': defaultPrice,
    };
    // v1.4.x documents PUT; older/deployed servers still expose PATCH. Try the
    // documented method first, fall back to PATCH if the server rejects PUT.
    try {
      await _client.putJson('/products/$id', body: body);
    } on ApiException catch (e) {
      if (e.status == 405 || e.code == 'HTTP_405') {
        await _client.patchJson('/products/$id', body: body);
      } else {
        rethrow;
      }
    }
  }

  // ── Mappers ────────────────────────────────────────────────────────────
  /// [fromList] items (ProductListItem) carry no stock — flagged as unknown
  /// (stock = -1) so the UI hides the stock badge until detail is loaded.
  static Product mapProduct(Map j, {bool fromList = false}) {
    // The API exposes no on-hand quantity on products (list or detail); stock is
    // unknown here (-1 → UI hides the badge) and derived later from the ledger.
    final hasOnHand = _pick(j, ['onHand']) != null;
    final onHand = hasOnHand ? _i(j, ['onHand']) : -1;
    final wh = <(String, int)>[];
    if (hasOnHand) wh.add(('On hand', onHand));
    return Product(
      id: _i(j, ['id', 'itemId']),
      code: _s(j, ['code']),
      name: _s(j, ['name'], 'Unnamed'),
      brand: _s(j, ['brand']),
      cat: _s(j, ['category'], ''),
      unit: _s(j, ['uom'], 'Unit'),
      price: _d(j, ['price', 'defaultPrice']),
      cost: _d(j, ['cost']),
      stock: onHand,
      barcode: _s(j, ['barcode']),
      wh: wh,
      images: mapProductImages(_pick(j, ['images'])),
    );
  }

  /// CustomerListItem / SupplierListItem → [Customer]. Customers carry an AR
  /// `outstanding`; per-bucket aging still comes from the statement.
  static Customer mapParty(Map j) {
    return Customer(
      id: _i(j, ['id']),
      name: _s(j, ['name'], 'Unnamed'),
      ar: '',
      area: _s(j, ['country', 'city']),
      phone: _s(j, ['phone', 'mobile']),
      limit: _d(j, ['creditLimit']),
      out: _d(j, ['outstanding']),
      aging: const [0, 0, 0, 0],
    );
  }

  static StatementResult mapStatement(Map j) {
    final linesRaw = _pick(j, ['lines']);
    final rows = <StmtRow>[];
    if (linesRaw is List) {
      for (final l in linesRaw.whereType<Map>()) {
        final inv = _d(l, ['invoice', 'debit']);
        final paid = _d(l, ['paid', 'credit']);
        rows.add(StmtRow(
          _fmtDate(_s(l, ['date'])),
          _s(l, ['docNumber', 'document']),
          inv == 0 ? null : inv,
          paid == 0 ? null : paid,
          _d(l, ['balance']),
        ));
      }
    }
    final ag = _pick(j, ['aging']);
    List<double> aging = const [0, 0, 0, 0];
    if (ag is Map) {
      aging = [
        _d(ag, ['current']),
        _d(ag, ['d30']),
        _d(ag, ['d60']),
        _d(ag, ['d90']) + _d(ag, ['d180']),
      ];
    }
    return StatementResult(
      rows: rows,
      opening: _d(j, ['openingBalance']),
      closing: _d(j, ['closingBalance']),
      aging: aging,
    );
  }

  static LedgerEntry mapLedger(Map j) {
    return LedgerEntry(
      _fmtDate(_s(j, ['date'])),
      _s(j, ['docNumber', 'document']),
      _i(j, ['qtyChange', 'qty']),
      _i(j, ['balance']),
    );
  }
}
