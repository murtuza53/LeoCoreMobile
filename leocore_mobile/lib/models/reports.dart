// Manager-report models (LeoCore ERP v1.4.5+). All are server-aggregated
// summaries — the app renders them directly. Parsing is tolerant: missing
// fields default to 0/empty so a partial server response never crashes the UI.

double _d(dynamic v) => v is num
    ? v.toDouble()
    : (v == null ? 0 : double.tryParse(v.toString().replaceAll(',', '')) ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (v == null ? 0 : int.tryParse(v.toString()) ?? 0);
String _s(dynamic v) => v?.toString() ?? '';
List _l(dynamic v) => v is List ? v : const [];
Map _m(dynamic v) => v is Map ? v : const {};

/// AR aging — company-wide outstanding by bucket. Gate: Finance Reports.
class AgingReport {
  final String asOn;
  final double total;
  final List<double> buckets; // [current, d30, d60, d90, d180plus]
  final List<AgingDebtor> topDebtors;
  const AgingReport({this.asOn = '', this.total = 0, this.buckets = const [0, 0, 0, 0, 0], this.topDebtors = const []});

  factory AgingReport.fromJson(Map j) {
    final b = _m(j['buckets']);
    return AgingReport(
      asOn: _s(j['asOn']),
      total: _d(j['total']),
      buckets: [_d(b['current']), _d(b['d30']), _d(b['d60']), _d(b['d90']), _d(b['d180plus'])],
      topDebtors: _l(j['topDebtors']).whereType<Map>().map(AgingDebtor.fromJson).toList(),
    );
  }
}

class AgingDebtor {
  final int customerId;
  final String name;
  final double outstanding;
  final int oldestDays;
  const AgingDebtor({required this.customerId, required this.name, required this.outstanding, required this.oldestDays});
  factory AgingDebtor.fromJson(Map j) => AgingDebtor(
        customerId: _i(j['customerId']),
        name: _s(j['name']),
        outstanding: _d(j['outstanding']),
        oldestDays: _i(j['oldestDays']),
      );
}

/// Collections over a period. Gate: Reports.
class CollectionsReport {
  final double total;
  final int count;
  final List<({String label, double amount})> byMethod;
  final List<({String label, double amount})> byDay;
  const CollectionsReport({this.total = 0, this.count = 0, this.byMethod = const [], this.byDay = const []});

  factory CollectionsReport.fromJson(Map j) => CollectionsReport(
        total: _d(j['total']),
        count: _i(j['count']),
        byMethod: _l(j['byMethod'])
            .whereType<Map>()
            .map((m) => (label: _s(m['method']), amount: _d(m['amount'])))
            .toList(),
        byDay: _l(j['byDay'])
            .whereType<Map>()
            .map((m) => (label: _s(m['date']), amount: _d(m['amount'])))
            .toList(),
      );
}

/// Cash & bank balances. Gate: Finance Reports.
class CashPosition {
  final double totalCash;
  final double totalBank;
  final List<({int accountId, String name, String type, double balance})> accounts;
  const CashPosition({this.totalCash = 0, this.totalBank = 0, this.accounts = const []});

  factory CashPosition.fromJson(Map j) => CashPosition(
        totalCash: _d(j['totalCash']),
        totalBank: _d(j['totalBank']),
        accounts: _l(j['accounts'])
            .whereType<Map>()
            .map((m) => (accountId: _i(m['accountId']), name: _s(m['name']), type: _s(m['type']), balance: _d(m['balance'])))
            .toList(),
      );
}

/// Sales trend (day/week/month). Gate: Reports.
class SalesTrendReport {
  final String groupBy;
  final double total;
  final double avgPerDay;
  final List<({String label, double sales, int invoices})> points;
  const SalesTrendReport({this.groupBy = 'day', this.total = 0, this.avgPerDay = 0, this.points = const []});

  factory SalesTrendReport.fromJson(Map j) => SalesTrendReport(
        groupBy: _s(j['groupBy']),
        total: _d(j['total']),
        avgPerDay: _d(j['avgPerDay']),
        points: _l(j['points'])
            .whereType<Map>()
            .map((m) => (label: _s(m['label']), sales: _d(m['sales']), invoices: _i(m['invoices'])))
            .toList(),
      );
}

/// Gross margin. Gate: Finance Reports.
class MarginReport {
  final double revenue;
  final double cost;
  final double grossProfit;
  final double marginPct;
  final List<({String name, double revenue, double margin})> byCategory;
  const MarginReport({this.revenue = 0, this.cost = 0, this.grossProfit = 0, this.marginPct = 0, this.byCategory = const []});

  factory MarginReport.fromJson(Map j) => MarginReport(
        revenue: _d(j['revenue']),
        cost: _d(j['cost']),
        grossProfit: _d(j['grossProfit']),
        marginPct: _d(j['marginPct']),
        byCategory: _l(j['byCategory'])
            .whereType<Map>()
            .map((m) => (name: _s(m['name']), revenue: _d(m['revenue']), margin: _d(m['margin'])))
            .toList(),
      );
}

/// Top-selling items. Gate: Reports.
class TopItemsReport {
  final String by; // value | qty
  final List<({int itemId, String code, String name, double qty, double value})> items;
  const TopItemsReport({this.by = 'value', this.items = const []});

  factory TopItemsReport.fromJson(Map j) => TopItemsReport(
        by: _s(j['by']),
        items: _l(j['items'])
            .whereType<Map>()
            .map((m) => (itemId: _i(m['itemId']), code: _s(m['code']), name: _s(m['name']), qty: _d(m['qty']), value: _d(m['value'])))
            .toList(),
      );
}

/// Sales by category. Gate: Reports.
class CategorySalesReport {
  final List<({String name, double sales, double qty})> categories;
  const CategorySalesReport({this.categories = const []});
  factory CategorySalesReport.fromJson(Map j) => CategorySalesReport(
        categories: _l(j['categories'])
            .whereType<Map>()
            .map((m) => (name: _s(m['name']), sales: _d(m['sales']), qty: _d(m['qty'])))
            .toList(),
      );
}

/// VAT summary. Gate: Finance Reports.
class VatReport {
  final double outputVat;
  final double inputVat;
  final double netPayable;
  const VatReport({this.outputVat = 0, this.inputVat = 0, this.netPayable = 0});
  factory VatReport.fromJson(Map j) =>
      VatReport(outputVat: _d(j['outputVat']), inputVat: _d(j['inputVat']), netPayable: _d(j['netPayable']));
}

/// Sales by salesman (via each customer's assigned employee). Gate: Reports.
class SalesmanReport {
  final List<({int salesmanId, String name, double sales, int invoices, double collections})> salesmen;
  const SalesmanReport({this.salesmen = const []});
  factory SalesmanReport.fromJson(Map j) => SalesmanReport(
        salesmen: _l(j['salesmen'])
            .whereType<Map>()
            .map((m) => (
                  salesmanId: _i(m['salesmanId']),
                  name: _s(m['name']),
                  sales: _d(m['sales']),
                  invoices: _i(m['invoices']),
                  collections: _d(m['collections']),
                ))
            .toList(),
      );
}

/// Inventory valuation at weighted-average cost. Gate: Finance Reports.
class InventoryValuation {
  final double totalValue;
  final double totalQty;
  final List<({String name, double value, double qty})> byCategory;
  final List<({String name, double value, double qty})> byWarehouse;
  const InventoryValuation({this.totalValue = 0, this.totalQty = 0, this.byCategory = const [], this.byWarehouse = const []});

  static List<({String name, double value, double qty})> _split(dynamic raw) => _l(raw)
      .whereType<Map>()
      .map((m) => (name: _s(m['name']), value: _d(m['value']), qty: _d(m['qty'])))
      .toList();

  factory InventoryValuation.fromJson(Map j) => InventoryValuation(
        totalValue: _d(j['totalValue']),
        totalQty: _d(j['totalQty']),
        byCategory: _split(j['byCategory']),
        byWarehouse: _split(j['byWarehouse']),
      );
}

/// A barcode/QR label template (designed in the web app). Gate: MobileLabels.
class LabelTemplate {
  final int id;
  final String name;
  final double widthMm;
  final double heightMm;
  const LabelTemplate({required this.id, required this.name, this.widthMm = 0, this.heightMm = 0});
  factory LabelTemplate.fromJson(Map j) => LabelTemplate(
        id: _i(j['id']),
        name: _s(j['name']),
        widthMm: _d(j['widthMm']),
        heightMm: _d(j['heightMm']),
      );
}
