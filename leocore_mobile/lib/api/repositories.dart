import 'package:intl/intl.dart';

import '../models/documents.dart';
import '../models/permissions.dart';
import '../models/models.dart';
import '../models/reports.dart';
import '../state/paged_list.dart';
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
  final String supplierCode;
  final int onHand;
  final int daysIdle;
  const StockRowData({
    required this.id,
    required this.code,
    required this.name,
    required this.barcode,
    required this.onHand,
    this.daysIdle = 0,
    this.supplierCode = '',
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
/// A row of the saved-quotations list (`GET /sales/quotations`).
class QuotationSummary {
  final int id;
  final String number;
  final DateTime? date;
  final DateTime? expiryDate;
  final String customer;
  final String status;
  final double grandTotal;
  final String currency;
  const QuotationSummary({
    required this.id,
    required this.number,
    this.date,
    this.expiryDate,
    this.customer = '',
    this.status = '',
    this.grandTotal = 0,
    this.currency = 'BHD',
  });

  factory QuotationSummary.fromJson(Map j) => QuotationSummary(
        id: _i(j, ['id']),
        number: _s(j, ['number']),
        date: DateTime.tryParse(_s(j, ['date'])),
        expiryDate: DateTime.tryParse(_s(j, ['expiryDate'])),
        customer: _s(j, ['customer']),
        status: _s(j, ['status']),
        grandTotal: _d(j, ['grandTotal']),
        currency: _s(j, ['currency'], 'BHD'),
      );
}

/// One line of a saved quotation. `unitPrice` is always excl. VAT (1.6.51+);
/// money shown to the user comes from `net` / `total`.
class QuotationLine {
  final String name;
  final double qty;
  final double unitPrice;
  final double net;
  final double total;
  const QuotationLine({required this.name, this.qty = 0, this.unitPrice = 0, this.net = 0, this.total = 0});

  factory QuotationLine.fromJson(Map j) => QuotationLine(
        // A typed line description overrides the item name.
        name: _s(j, ['description']).trim().isNotEmpty ? _s(j, ['description']).trim() : _s(j, ['name']),
        qty: _d(j, ['qty']),
        unitPrice: _d(j, ['unitPrice']),
        net: _d(j, ['net']),
        total: _d(j, ['total']),
      );
}

/// A saved quotation with its lines (`GET /sales/quotations/{id}`).
class QuotationDetail {
  final QuotationSummary head;
  final double subTotal;
  final double discount;
  final double vatAmount;
  final String notes;
  final List<QuotationLine> lines;
  const QuotationDetail({
    required this.head,
    this.subTotal = 0,
    this.discount = 0,
    this.vatAmount = 0,
    this.notes = '',
    this.lines = const [],
  });

  factory QuotationDetail.fromJson(Map j) {
    final c = j['customer'];
    return QuotationDetail(
      head: QuotationSummary(
        id: _i(j, ['id']),
        number: _s(j, ['number']),
        date: DateTime.tryParse(_s(j, ['date'])),
        expiryDate: DateTime.tryParse(_s(j, ['expiryDate'])),
        customer: c is Map ? _s(c, ['name']) : _s(j, ['customer']),
        status: _s(j, ['status']),
        grandTotal: _d(j, ['grandTotal']),
        currency: _s(j, ['currency'], 'BHD'),
      ),
      subTotal: _d(j, ['subTotal']),
      discount: _d(j, ['discount']),
      vatAmount: _d(j, ['vatAmount']),
      notes: _s(j, ['notes']),
      lines: [
        for (final l in (j['lines'] is List ? j['lines'] as List : const [])) if (l is Map) QuotationLine.fromJson(l),
      ],
    );
  }
}

/// A warehouse the user can pick (branch = the branch it belongs to; '' on older servers).
typedef WarehouseOpt = ({int id, String code, String name, String branch});

/// A stock count sheet on the server that is not processed yet: Draft (still counting), Unprocessed (counting done,
/// waiting for the web app) or Failed (a processing run failed). The phone can open, edit and delete it; only the web
/// app processes it (as of its count date). [id] 0 = a new sheet not saved yet.
class CountSheet {
  final int id;
  final String number;
  final DateTime date;
  final int warehouseId;
  final String warehouseName;
  final String branchName;
  final String notes;
  final String status;
  final String message;
  final int lines;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;
  const CountSheet({
    required this.id,
    required this.number,
    required this.date,
    required this.warehouseId,
    this.warehouseName = '',
    this.branchName = '',
    this.notes = '',
    this.status = 'Draft',
    this.message = '',
    this.lines = 0,
    this.createdBy = '',
    this.updatedAt,
    this.updatedBy = '',
  });

  bool get failed => status == 'Failed';
  bool get ready => status == 'Unprocessed';

  CountSheet copyWith({int? id, String? number, DateTime? date, int? warehouseId, String? warehouseName, String? branchName, String? notes, String? status, int? lines}) =>
      CountSheet(
        id: id ?? this.id,
        number: number ?? this.number,
        date: date ?? this.date,
        warehouseId: warehouseId ?? this.warehouseId,
        warehouseName: warehouseName ?? this.warehouseName,
        branchName: branchName ?? this.branchName,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        message: message,
        lines: lines ?? this.lines,
        createdBy: createdBy,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );

  static DateTime? _dt(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

  factory CountSheet.fromJson(Map j) => CountSheet(
        id: _i(j, ['id']),
        number: _s(j, ['number']),
        date: DateTime.tryParse(_s(j, ['date'])) ?? DateTime.now(),
        warehouseId: _i(j, ['warehouseId']),
        warehouseName: _s(j, ['warehouseName']),
        branchName: _s(j, ['branchName']),
        notes: _s(j, ['notes']),
        status: _s(j, ['status'], 'Draft'),
        message: _s(j, ['message']),
        lines: j['lines'] is List ? (j['lines'] as List).length : _i(j, ['lines']),
        createdBy: _s(j, ['createdBy']),
        updatedAt: _dt(j['updatedAt']),
        updatedBy: _s(j, ['updatedBy']),
      );
}

/// A counted line of a [CountSheet]: the quantity in its unit ([uomId]; 0 = the base unit), who counted it and when
/// (local time). One item can have a line per unit (5 Bag + 4 Kg).
class CountSheetLine {
  final CountSheetRow row;
  final int uomId;
  final int quantity;
  final String notes;
  final String countedBy;
  final DateTime? countedAt;
  const CountSheetLine({required this.row, required this.quantity, this.uomId = 0, this.notes = '', this.countedBy = '', this.countedAt});

  factory CountSheetLine.fromJson(Map m) => CountSheetLine(
        row: CountSheetRow(
          itemId: _i(m, ['itemId']),
          code: _s(m, ['code']),
          name: _s(m, ['name']),
          barcode: _s(m, ['barcode']),
          supplierCode: _s(m, ['supplierCode']),
          expected: _i(m, ['systemQty']),
          uom: _s(m, ['baseUomCode', 'uomCode']),
          units: CountUnit.listFrom(m['units']),
        ),
        uomId: _i(m, ['uomId']),
        // older servers send only countedQty (base unit)
        quantity: m['quantity'] != null ? _i(m, ['quantity']) : _i(m, ['countedQty']),
        notes: _s(m, ['notes']),
        countedBy: _s(m, ['countedBy']),
        countedAt: CountSheet._dt(m['countedAt']),
      );
}

/// A unit an item can be counted in: its base unit (factor 1) or a larger one (Bag of 15 Kg = factor 15).
class CountUnit {
  final int id;
  final String code;
  final double factor;
  final bool isBase;
  const CountUnit({required this.id, required this.code, this.factor = 1, this.isBase = false});

  static List<CountUnit> listFrom(dynamic raw) => raw is List
      ? [
          for (final u in raw.whereType<Map>())
            CountUnit(id: _i(u, ['id']), code: _s(u, ['code']), factor: _d(u, ['factor']) <= 0 ? 1 : _d(u, ['factor']), isBase: u['isBase'] == true)
        ]
      : const [];
}

/// A row of the stock-count sheet. [expected] and every total are in the base unit [uom]; [units] are the units it
/// can be counted in (base first; empty from older servers = base only).
class CountSheetRow {
  final int itemId;
  final String code;
  final String name;
  final String barcode;
  final String supplierCode;
  final int expected;
  final String uom;
  final List<CountUnit> units;
  const CountSheetRow({
    required this.itemId,
    required this.code,
    required this.name,
    required this.barcode,
    required this.expected,
    this.supplierCode = '',
    this.uom = '',
    this.units = const [],
  });

  /// The unit with [id] (0 or unknown = the base unit).
  CountUnit unit(int id) =>
      units.where((u) => u.id == id).firstOrNull ??
      units.where((u) => u.isBase).firstOrNull ??
      CountUnit(id: 0, code: uom, isBase: true);

  /// The base unit's id (0 when the server sent no units).
  int get baseUnitId => units.where((u) => u.isBase).firstOrNull?.id ?? 0;
}

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

  /// One page of products. `search` (each word, anywhere) matches id, code, name, barcode, supplier code, brand
  /// or category on the server.
  Future<PageResult<Product>> productsPage({String? search, int? categoryId, int page = 1, int pageSize = 50}) async {
    final r = await _client.getPage('/products', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': categoryId,
    });
    return PageResult(r.items.whereType<Map>().map((m) => mapProduct(m, fromList: true)).toList(), r.hasMore);
  }

  Future<Product> product(int id) async {
    final j = await _client.getJson('/products/$id');
    return mapProduct(j);
  }

  Future<Product> productByBarcode(String code) async {
    final j = await _client.getJson('/products/by-barcode/$code');
    return mapProduct(j);
  }

  Future<List<({int id, String name})>> categories() async {
    final list = await _client.getList('/categories');
    return list
        .whereType<Map>()
        .map((m) => (id: _i(m, ['id']), name: _s(m, ['name'])))
        .where((c) => c.name.isNotEmpty)
        .toList();
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

  /// One page of customers or suppliers ([party] = 'customers' | 'suppliers').
  /// `search` matches name, email, phone, VAT/TRN or id; [hideZero] keeps
  /// only parties with an outstanding balance; [byBalance] sorts largest first.
  Future<PageResult<Customer>> partiesPage(
    String party, {
    String? search,
    bool hideZero = false,
    bool byBalance = false,
    int page = 1,
    int pageSize = 50,
  }) async {
    final r = await _client.getPage('/$party', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (hideZero) 'balance': 'nonzero',
      if (byBalance) 'sort': 'balance',
    });
    return PageResult(r.items.whereType<Map>().map(mapParty).toList(), r.hasMore);
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
  /// The server prices lines without a manual `price` from the price list, so
  /// the totals come back from it.
  Future<SalesDocResult> createCashInvoiceDraft({
    required int warehouseId,
    int? customerId,
    required List<({int itemId, int qty, double? price})> lines,
    required String idempotencyKey,
  }) async {
    final j = await _client.postJson(
      '/sales/cash-invoice/draft',
      idempotencyKey: idempotencyKey,
      body: {
        'warehouseId': warehouseId,
        if (customerId != null) 'customerId': customerId,
        'lines': [
          for (final l in lines) {'itemId': l.itemId, 'qty': l.qty, if (l.price != null) 'price': l.price},
        ],
      },
    );
    return SalesDocResult.fromJson(j);
  }

  Future<SalesDocResult> createQuotation({
    required int customerId,
    required List<({int itemId, int qty, double? price})> lines,
    required String idempotencyKey,
  }) async {
    final j = await _client.postJson(
      '/sales/quotations',
      idempotencyKey: idempotencyKey,
      body: {
        'customerId': customerId,
        'lines': [
          for (final l in lines) {'itemId': l.itemId, 'qty': l.qty, if (l.price != null) 'price': l.price},
        ],
      },
    );
    return SalesDocResult.fromJson(j);
  }

  /// Saved quotations, newest first. `search` matches number, customer or
  /// reference.
  Future<PageResult<QuotationSummary>> quotations({String? search, int page = 1, int pageSize = 30}) async {
    final r = await _client.getPage('/sales/quotations', query: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return PageResult(r.items.whereType<Map>().map(QuotationSummary.fromJson).toList(), r.hasMore);
  }

  Future<QuotationDetail> quotation(int id) async =>
      QuotationDetail.fromJson(await _client.getJson('/sales/quotations/$id'));

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

  // ── Manager reports (v1.4.5+, RBAC-gated) ──────────────────────────────
  Future<AgingReport> receivablesAging({String? asOn}) async =>
      AgingReport.fromJson(await _client.getJson('/reports/receivables/aging',
          query: {if (asOn != null) 'asOn': asOn}));

  Future<CollectionsReport> collections({required String from, required String to}) async =>
      CollectionsReport.fromJson(await _client.getJson('/reports/collections', query: {'from': from, 'to': to}));

  Future<CashPosition> cashPosition({String? asOn}) async =>
      CashPosition.fromJson(await _client.getJson('/reports/cash-position', query: {if (asOn != null) 'asOn': asOn}));

  Future<SalesTrendReport> salesTrend({required String from, required String to, String groupBy = 'day'}) async =>
      SalesTrendReport.fromJson(await _client.getJson('/reports/sales/trend', query: {'from': from, 'to': to, 'groupBy': groupBy}));

  Future<MarginReport> margin({required String from, required String to}) async =>
      MarginReport.fromJson(await _client.getJson('/reports/margin', query: {'from': from, 'to': to}));

  Future<TopItemsReport> topItems({required String from, required String to, int limit = 10, String by = 'value'}) async =>
      TopItemsReport.fromJson(await _client.getJson('/reports/top-items', query: {'from': from, 'to': to, 'limit': limit, 'by': by}));

  Future<CategorySalesReport> salesByCategory({required String from, required String to}) async =>
      CategorySalesReport.fromJson(await _client.getJson('/reports/sales/by-category', query: {'from': from, 'to': to}));

  Future<VatReport> vat({required String from, required String to}) async =>
      VatReport.fromJson(await _client.getJson('/reports/vat', query: {'from': from, 'to': to}));

  Future<SalesmanReport> salesBySalesman({required String from, required String to}) async =>
      SalesmanReport.fromJson(await _client.getJson('/reports/sales/by-salesman', query: {'from': from, 'to': to}));

  Future<InventoryValuation> inventoryValuation({int? warehouseId}) async =>
      InventoryValuation.fromJson(await _client.getJson('/reports/inventory/valuation',
          query: {if (warehouseId != null) 'warehouseId': warehouseId}));

  // ── Attach Docs (1.6.x, gate: MobileDocuments) ─────────────────────────
  Future<DocLookup> documentLookup(String number) async {
    final j = await _client.getJson('/documents/lookup', query: {'number': number});
    return DocLookup.fromJson(j);
  }

  /// Attaches one or more files to the document with [number] (multipart;
  /// repeatable `files` part).
  Future<AttachResult> attachDocuments(String number, List<String> filePaths) async {
    final j = await _client.postMultipart(
      '/documents/attach',
      field: 'files',
      filePaths: filePaths,
      fields: {'number': number},
    );
    return AttachResult.fromJson(j);
  }

  Future<List<DocAttachment>> documentAttachments(String docType, int docId) async {
    final j = await _client.getJson('/documents/$docType/$docId/attachments');
    return parseAttachments(_pick(j, ['attachments'])) ?? const [];
  }

  /// The attachment's file, fetched with the Bearer token (1.6.52+).
  Future<({List<int> bytes, String filename, String contentType})> attachmentFile(DocAttachment a) =>
      _client.downloadBytes('/documents/attachments/${a.id}/file', fallbackName: a.fileName);

  /// Deletes an attachment (record and stored file); returns what is left.
  Future<List<DocAttachment>> deleteAttachment(int id) async {
    final j = await _client.deleteJson('/documents/attachments/$id');
    return parseAttachments(_pick(j, ['attachments'])) ?? const [];
  }

  // ── Barcode labels (v1.4.7, gate: MobileLabels) ────────────────────────
  /// Templates plus an optional empty-state message (server-provided when no
  /// label designs exist).
  Future<({List<LabelTemplate> templates, String? message})> labelTemplates() async {
    final j = await _client.getJson('/label-templates');
    final raw = _pick(j, ['templates']);
    final templates = (raw is List ? raw : const []).whereType<Map>().map(LabelTemplate.fromJson).toList();
    final hasLabels = _pick(j, ['hasLabels']);
    final msg = _s(j, ['message']);
    final emptyMessage = ((hasLabels == false || templates.isEmpty) && msg.isNotEmpty) ? msg : null;
    return (templates: templates, message: emptyMessage);
  }

  /// Renders a print-ready label PDF for the given items/quantities.
  Future<({List<int> bytes, String filename, String contentType})> printLabels({
    required int templateId,
    required List<({int itemId, int quantity})> items,
  }) {
    return _client.postBytes(
      '/labels/print',
      fallbackName: 'labels_$templateId.pdf',
      body: {
        'templateId': templateId,
        'items': [for (final it in items) {'itemId': it.itemId, 'quantity': it.quantity}],
      },
    );
  }

  // ── Receipts / collections (gate: RBAC on role) ────────────────────────
  Future<SalesDocResult> postReceipt({
    required int customerId,
    required int accountId,
    required double amount,
    String paymentMethod = 'Cash',
    String? reference,
    List<({String docType, int docId, double amount})> allocations = const [],
    required String idempotencyKey,
  }) async {
    final j = await _client.postJson(
      '/receipts',
      idempotencyKey: idempotencyKey,
      body: {
        'customerId': customerId,
        'accountId': accountId,
        'paymentMethod': paymentMethod,
        'amount': amount,
        if (reference != null) 'reference': reference,
        'allocations': [
          for (final a in allocations) {'docType': a.docType, 'docId': a.docId, 'amount': a.amount}
        ],
      },
    );
    return SalesDocResult.fromJson(j);
  }

  // ── Payment tenders (cash/bank accounts) ───────────────────────────────
  Future<List<({int accountId, String name, String type})>> tenders() async {
    final list = await _client.getList('/sales/tenders');
    return list
        .whereType<Map>()
        .map((m) => (accountId: _i(m, ['accountId', 'id']), name: _s(m, ['name']), type: _s(m, ['type'])))
        .toList();
  }

  // ── Customer outstanding (open invoices) ───────────────────────────────
  Future<({double balance, List<({int docId, String number, String date, double amount, double balance, int overdueDays})> invoices})>
      customerOutstanding(int id) async {
    final j = await _client.getJson('/customers/$id/outstanding');
    final rows = _pick(j, ['invoices', 'items', 'lines']);
    return (
      balance: _d(j, ['balance', 'total', 'outstanding']),
      invoices: (rows is List ? rows : const [])
          .whereType<Map>()
          .map((m) => (
                docId: _i(m, ['docId', 'id']),
                number: _s(m, ['number', 'docNumber']),
                date: _fmtDate(_s(m, ['date'])),
                amount: _d(m, ['amount', 'total']),
                balance: _d(m, ['balance', 'outstanding']),
                overdueDays: _i(m, ['overdueDays', 'daysOverdue']),
              ))
          .toList(),
    );
  }

  // ── Live stock count (sheet + submit) ──────────────────────────────────
  /// One page of the count sheet: stock items with the system quantity in
  /// [warehouseId]. `search` (each word, anywhere) matches name, code, barcode or supplier code.
  /// [date] / [sheetId]: expected quantities are the stock at the end of the sheet's count date (what the web
  /// processes against), leaving out that sheet's own adjustments.
  Future<PageResult<CountSheetRow>> stockCountSheet({
    required int warehouseId,
    String? search,
    int page = 1,
    int pageSize = 50,
    DateTime? date,
    int sheetId = 0,
  }) async {
    final r = await _client.getPage('/inventory/stock-count/sheet', query: {
      'page': page,
      'pageSize': pageSize,
      'warehouseId': warehouseId,
      if (date != null) 'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (sheetId > 0) 'sheetId': sheetId,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return PageResult(
      r.items
          .whereType<Map>()
          .map((m) => CountSheetRow(
                itemId: _i(m, ['itemId', 'id']),
                code: _s(m, ['code']),
                name: _s(m, ['name']),
                barcode: _s(m, ['barcode']),
                supplierCode: _s(m, ['supplierCode']),
                expected: _i(m, ['systemQty', 'expected', 'onHand']),
                uom: _s(m, ['uomCode', 'uom']),
                units: CountUnit.listFrom(m['units']),
              ))
          .toList(),
      r.hasMore,
    );
  }

  // ── Count sheets (unprocessed; processed only on the web) ───────────────
  /// Every unprocessed count sheet, newest date first.
  Future<List<CountSheet>> stockCounts() async {
    final list = await _client.getList('/inventory/stock-counts');
    return list.whereType<Map>().map(CountSheet.fromJson).toList();
  }

  /// One sheet with its counted lines. 404 = processed or deleted meanwhile.
  Future<({CountSheet sheet, List<CountSheetLine> lines})> stockCount(int id) async {
    final j = await _client.getJson('/inventory/stock-counts/$id');
    return (
      sheet: CountSheet.fromJson(j),
      lines: [for (final l in (j['lines'] is List ? j['lines'] as List : const [])) if (l is Map) CountSheetLine.fromJson(l)],
    );
  }

  /// Save a sheet: id 0 creates it (on [date], in [warehouseId]), otherwise its lines become exactly [lines].
  /// [status]: 'Draft' (still counting) or 'Unprocessed' (ready to be processed on the web); null keeps it.
  Future<CountSheet> saveStockCount({
    required int id,
    required int warehouseId,
    required DateTime date,
    String? notes,
    String? status,
    required List<({int itemId, int uomId, int quantity, String notes})> lines,
    String? idempotencyKey,
  }) async {
    final body = {
      'warehouseId': warehouseId,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'notes': notes,
      if (status != null) 'status': status,
      // One line per item AND unit: [quantity] is in that unit (uomId 0 = the base unit, sent as countedQty).
      'lines': [
        for (final l in lines)
          {
            'itemId': l.itemId,
            if (l.uomId > 0) ...{'uomId': l.uomId, 'quantity': l.quantity} else 'countedQty': l.quantity,
            if (l.notes.isNotEmpty) 'notes': l.notes,
          }
      ],
    };
    final j = id == 0
        ? await _client.postJson('/inventory/stock-count', idempotencyKey: idempotencyKey, body: body)
        : await _client.putJson('/inventory/stock-counts/$id', body: body);
    return CountSheet.fromJson(j);
  }

  Future<void> deleteStockCount(int id) => _client.deleteJson('/inventory/stock-counts/$id');

  static List<ProductImage> mapProductImages(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      return ProductImage(
        id: _i(m, ['id']),
        url: _s(m, ['url']),
        thumbUrl: _s(m, ['thumbUrl']),
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

  Future<List<WarehouseOpt>> warehouses() async {
    final list = await _client.getList('/warehouses');
    return list
        .whereType<Map>()
        .map((m) => (id: _i(m, ['id']), code: _s(m, ['code']), name: _s(m, ['name'], 'Warehouse'), branch: _s(m, ['branchName'])))
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
        supplierCode: _s(j, ['supplierCode']),
        onHand: _i(j, ['onHand']),
        daysIdle: _i(j, ['daysIdle']),
      );

  // ── Menu (permission-filtered) ─────────────────────────────────────────
  /// The user's rights per mobile page (role permission page → Mobile App tab).
  Future<MobilePermissions> permissions() async =>
      MobilePermissions.fromMenu(await _client.getJson('/menu'));

  Future<void> updateProduct(int id, {String? barcode, String? model, double? defaultPrice}) async {
    final body = {
      if (barcode != null) 'barcode': barcode,
      if (model != null) 'model': model,
      if (defaultPrice != null) 'defaultPrice': defaultPrice,
    };
    // The server route is PATCH (MOBILE_API.md §6; earlier editions said PUT).
    await _client.patchJson('/products/$id', body: body);
  }

  // ── Mappers ────────────────────────────────────────────────────────────
  // On-hand quantity (base unit, summed across warehouses; may be 0 or
  // negative/oversold). As of LeoCore 1.6.25 it's on the list too, under
  // `onHand`. If ever omitted, stock stays unknown (kUnknownStock → "—").
  static const _stockKeys = [
    'onHand', 'onHandQty', 'qtyOnHand', 'quantityOnHand', 'availableQuantity',
    'availableQty', 'available', 'stock', 'stockQty', 'stockOnHand',
    'currentStock', 'balance', 'balanceQty', 'quantity'
  ];
  // Selling / list price may be exposed under any of these names.
  static const _priceKeys = [
    'price', 'defaultPrice', 'listPrice', 'salePrice', 'sellingPrice',
    'unitPrice', 'retailPrice'
  ];

  static Product mapProduct(Map j, {bool fromList = false}) {
    final hasOnHand = _pick(j, _stockKeys) != null;
    final onHand = hasOnHand ? _i(j, _stockKeys) : kUnknownStock;
    final wh = <(String, int)>[];
    if (hasOnHand) wh.add(('On hand', onHand));
    // Detail returns images[]; the list returns a single imageUrl. Fold a bare
    // imageUrl into one image so the list row can show a thumbnail too.
    var images = mapProductImages(_pick(j, ['images']));
    if (images.isEmpty) {
      final single = _s(j, ['imageUrl', 'image', 'thumbnailUrl']);
      if (single.isNotEmpty) {
        images = [ProductImage(id: 0, url: single, thumbUrl: _s(j, ['thumbUrl']), isPrimary: true)];
      }
    }
    return Product(
      id: _i(j, ['id', 'itemId']),
      code: _s(j, ['code']),
      name: _s(j, ['name'], 'Unnamed'),
      brand: _s(j, ['brand']),
      cat: _s(j, ['category'], ''),
      unit: _s(j, ['uom'], 'Unit'),
      price: _d(j, _priceKeys),
      cost: _d(j, ['cost', 'costPrice', 'avgCost', 'averageCost']),
      stock: onHand,
      barcode: _s(j, ['barcode']),
      supplierCode: _s(j, ['supplierCode']),
      wh: wh,
      images: images,
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
