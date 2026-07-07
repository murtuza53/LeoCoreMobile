import '../models/models.dart';
import '../utils/money.dart';

/// Mock dataset, copied 1:1 from the design prototype's in-component store so
/// the UI renders identical numbers. Swapped for API responses in a later pass.
class MockData {
  static const List<Product> products = [
    Product(id: 1, code: 'MLK-0421', name: 'Almarai Full Fat Milk 2L', brand: 'Almarai', cat: 'Dairy', unit: 'Bottle', price: 1.250, cost: 0.980, stock: 184, barcode: '6281007021234', wh: [('Main WH · Tubli', 120), ('Van 12 · Yousif', 24), ('Sitra Store', 40)]),
    Product(id: 2, code: 'SGR-1105', name: 'Al Osra Sugar 5kg', brand: 'Al Osra', cat: 'Grocery', unit: 'Bag', price: 2.100, cost: 1.720, stock: 312, barcode: '6281100554321', wh: [('Main WH · Tubli', 260), ('Van 12 · Yousif', 12), ('Sitra Store', 40)]),
    Product(id: 3, code: 'CHK-0808', name: 'Sadia Frozen Chicken 1000g', brand: 'Sadia', cat: 'Frozen', unit: 'Piece', price: 1.450, cost: 1.180, stock: 96, barcode: '7891515308087', wh: [('Main WH · Tubli', 80), ('Van 12 · Yousif', 0), ('Sitra Store', 16)]),
    Product(id: 4, code: 'TEA-0330', name: 'Lipton Yellow Label 200s', brand: 'Lipton', cat: 'Beverages', unit: 'Box', price: 2.850, cost: 2.310, stock: 58, barcode: '6281006543308', wh: [('Main WH · Tubli', 44), ('Van 12 · Yousif', 6), ('Sitra Store', 8)]),
    Product(id: 5, code: 'WTR-0102', name: 'Aquafina Water 1.5L ×12', brand: 'Aquafina', cat: 'Beverages', unit: 'Shrink', price: 1.150, cost: 0.890, stock: 22, barcode: '6281036101020', wh: [('Main WH · Tubli', 18), ('Van 12 · Yousif', 4), ('Sitra Store', 0)]),
    Product(id: 6, code: 'DET-0715', name: 'Tide Automatic 3kg', brand: 'Tide', cat: 'Household', unit: 'Box', price: 3.400, cost: 2.750, stock: 8, barcode: '6281031107157', wh: [('Main WH · Tubli', 8), ('Van 12 · Yousif', 0), ('Sitra Store', 0)]),
    Product(id: 7, code: 'RCE-0207', name: 'Mahmood Basmati Rice 5kg', brand: 'Mahmood', cat: 'Grocery', unit: 'Bag', price: 4.950, cost: 4.050, stock: 145, barcode: '6281101020075', wh: [('Main WH · Tubli', 110), ('Van 12 · Yousif', 15), ('Sitra Store', 20)]),
    Product(id: 8, code: 'OIL-0501', name: 'Noor Sunflower Oil 1.8L', brand: 'Noor', cat: 'Grocery', unit: 'Bottle', price: 1.980, cost: 1.610, stock: 0, barcode: '6281105010501', wh: [('Main WH · Tubli', 0), ('Van 12 · Yousif', 0), ('Sitra Store', 0)]),
  ];

  static const List<Customer> customers = [
    Customer(id: 1, name: 'Al Jazira Supermarket', ar: 'سوبرماركت الجزيرة', area: 'Manama', phone: '+973 3312 4567', limit: 5000, out: 2450.750, aging: [1200.500, 850.250, 400.000, 0]),
    Customer(id: 2, name: 'Gulf Mart WLL', ar: 'جلف مارت ذ.م.م', area: 'Riffa', phone: '+973 3945 8812', limit: 8000, out: 5120.000, aging: [2100.000, 1520.000, 900.000, 600.000]),
    Customer(id: 3, name: 'Manama Central Cold Store', ar: 'برادات المنامة المركزية', area: 'Manama', phone: '+973 3661 2044', limit: 2000, out: 890.500, aging: [890.500, 0, 0, 0]),
    Customer(id: 4, name: 'Awal Trading Co.', ar: 'شركة أوال للتجارة', area: 'Muharraq', phone: '+973 3877 3390', limit: 3000, out: 0, aging: [0, 0, 0, 0]),
    Customer(id: 5, name: 'Bahrain Pearl Markets', ar: 'أسواق لؤلؤة البحرين', area: 'Isa Town', phone: '+973 3520 9977', limit: 6000, out: 3275.250, aging: [800.250, 500.000, 1100.000, 875.000]),
    Customer(id: 6, name: 'Sitra Foodstuff Est.', ar: 'مؤسسة سترة للمواد الغذائية', area: 'Sitra', phone: '+973 3719 5566', limit: 2500, out: 1540.000, aging: [940.000, 600.000, 0, 0]),
  ];

  static const List<LedgerEntry> ledger = [
    LedgerEntry('02 Jul 2026', 'INV-10496', -6, 184),
    LedgerEntry('30 Jun 2026', 'GRN-2231', 120, 190),
    LedgerEntry('28 Jun 2026', 'INV-10441', -12, 70),
    LedgerEntry('25 Jun 2026', 'TRF-0710', -24, 82),
    LedgerEntry('21 Jun 2026', 'INV-10380', -18, 106),
    LedgerEntry('18 Jun 2026', 'ADJ-0092', 4, 124),
  ];

  static const List<StmtRow> stmt = [
    StmtRow('01 Jun 2026', 'Opening balance', null, null, 1980.500),
    StmtRow('04 Jun 2026', 'INV-10312', 412.750, null, 2393.250),
    StmtRow('09 Jun 2026', 'RCT-2210 · Cash', null, 500.000, 1893.250),
    StmtRow('14 Jun 2026', 'INV-10358', 640.000, null, 2533.250),
    StmtRow('20 Jun 2026', 'CN-0087 · Return', null, 82.500, 2450.750),
    StmtRow('27 Jun 2026', 'INV-10441', 385.250, null, 2836.000),
    StmtRow('01 Jul 2026', 'RCT-2288 · Benefit', null, 385.250, 2450.750),
  ];

  /// Expected counts for the stock-count session, keyed by product id.
  static const Map<int, int> expected = {1: 120, 3: 80, 5: 18, 6: 8};

  static const List<DeadRow> deadRows = [
    DeadRow('Eid Gift Tin Assortment 2024', 'GFT-0924', 34, 312, 34 * 2.4),
    DeadRow('Summer Cooler Jug 4L', 'HSW-0455', 18, 224, 18 * 1.85),
    DeadRow('Ramadan Dates Box 800g (2025)', 'DTS-0311', 26, 138, 26 * 3.1),
  ];

  static const List<String> categories = [
    'All', 'Dairy', 'Grocery', 'Beverages', 'Frozen', 'Household',
  ];

  static Product byId(int id) =>
      products.firstWhere((p) => p.id == id, orElse: () => products.first);

  /// Two-letter initials from a name, e.g. "Almarai Full…" → "AF".
  static String initials(String name) {
    final parts = name.split(' ').where((w) => w.isNotEmpty).take(2);
    return parts.map((w) => w[0]).join().toUpperCase();
  }

  /// Formats a customer's outstanding as a fixed 3-decimal string.
  static String money(double n) => Money.fmt(n);
}
