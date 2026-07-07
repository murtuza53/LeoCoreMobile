// Plain data models for the LeoCore ERP Mobile prototype.
//
// These mirror the shapes used by the design prototype's mock store. When the
// real `/api/mobile/v1` API is wired in, these become the deserialization
// targets (freezed/json_serializable) — the UI already speaks this vocabulary.

class Product {
  final int id;
  final String code;
  final String name;
  final String brand;
  final String cat;
  final String unit;
  final double price;
  final double cost;
  final int stock;
  final String barcode;

  /// (warehouse name, quantity) pairs.
  final List<(String, int)> wh;

  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.brand,
    required this.cat,
    required this.unit,
    required this.price,
    required this.cost,
    required this.stock,
    required this.barcode,
    required this.wh,
  });

  Product copyWith({int? stock, List<(String, int)>? wh}) => Product(
        id: id,
        code: code,
        name: name,
        brand: brand,
        cat: cat,
        unit: unit,
        price: price,
        cost: cost,
        stock: stock ?? this.stock,
        barcode: barcode,
        wh: wh ?? this.wh,
      );
}

class Customer {
  final int id;
  final String name;
  final String ar;
  final String area;
  final String phone;
  final double limit;
  final double out;

  /// Aging buckets: [0–30, 31–60, 61–90, 90+].
  final List<double> aging;

  const Customer({
    required this.id,
    required this.name,
    required this.ar,
    required this.area,
    required this.phone,
    required this.limit,
    required this.out,
    required this.aging,
  });
}

class LedgerEntry {
  final String d;
  final String doc;
  final int qty;
  final int bal;
  const LedgerEntry(this.d, this.doc, this.qty, this.bal);
}

class StmtRow {
  final String d;
  final String doc;
  final double? dr;
  final double? cr;
  final double bal;
  const StmtRow(this.d, this.doc, this.dr, this.cr, this.bal);
}

class DeadRow {
  final String name;
  final String code;
  final int qty;
  final int days;
  final double val;
  const DeadRow(this.name, this.code, this.qty, this.days, this.val);
}

class CartLine {
  int pid;
  int qty;
  CartLine(this.pid, this.qty);
}
