/// What the signed-in user may do in each mobile page, from GET /menu.
///
/// The server's role permission page has a "Mobile App" tab with one row per
/// mobile page (FeatureCatalog key, e.g. `MobileCashSales`) and the rights
/// View / Create / Edit / Delete / Print / Email. Menu v2 sends those rights per
/// feature, so the app shows a page only with View and each button only with
/// its right. The server enforces the same rules on every call; this only
/// keeps the app from offering what would be refused.
class Rights {
  final bool view, create, edit, delete, print, email;
  const Rights({
    this.view = false,
    this.create = false,
    this.edit = false,
    this.delete = false,
    this.print = false,
    this.email = false,
  });

  static const none = Rights();
  static const all = Rights(view: true, create: true, edit: true, delete: true, print: true, email: true);

  factory Rights.fromJson(Map j) {
    bool b(String k) => j[k] == true;
    return Rights(view: b('view'), create: b('create'), edit: b('edit'), delete: b('delete'), print: b('print'), email: b('email'));
  }
}

/// Mobile App feature keys (server FeatureCatalog, "Mobile App" group).
class Feat {
  static const access = 'MobileAccess';
  static const dashboard = 'MobileDashboard';
  static const products = 'MobileProducts';
  static const labels = 'MobileLabels';
  static const customers = 'MobileCustomers';
  static const suppliers = 'MobileSuppliers';
  static const statements = 'MobileStatements';
  static const stockLedger = 'MobileStockLedger';
  static const stockAlerts = 'MobileStockAlerts';
  static const reports = 'MobileReports';
  static const financeReports = 'MobileFinanceReports';
  static const cashSales = 'MobileCashSales';
  static const quotations = 'MobileQuotations';
  static const stockCount = 'MobileStockCount';
  static const receipts = 'MobileReceipts';
  static const documents = 'MobileDocuments';
}

class MobilePermissions {
  /// False until a menu has been read. While unknown the app doesn't hide
  /// anything (the server still refuses what isn't allowed), so a failed menu
  /// download never leaves the user with an empty app.
  final bool known;
  final Map<String, Rights> _byFeature;
  const MobilePermissions._(this.known, this._byFeature);

  static const unknown = MobilePermissions._(false, {});

  Rights of(String feature) => known ? (_byFeature[feature] ?? Rights.none) : Rights.all;

  /// Menu v2 carries `permissions` (every Mobile App feature). A v1 server
  /// only lists the pages the user can view, with `canEdit`; that is mapped
  /// to the same features, keeping what older app builds allowed.
  factory MobilePermissions.fromMenu(Map j) {
    final perms = j['permissions'];
    if (perms is Map) {
      return MobilePermissions._(true, {
        for (final e in perms.entries)
          if (e.value is Map) e.key.toString(): Rights.fromJson(e.value as Map),
      });
    }
    const v1 = {
      'dashboard': Feat.dashboard,
      'products': Feat.products,
      'labels': Feat.labels,
      'customers': Feat.customers,
      'suppliers': Feat.suppliers,
      'statements': Feat.statements,
      'stock-ledger': Feat.stockLedger,
      'reports': Feat.reports,
      'cash-sale': Feat.cashSales,
      'stock-count': Feat.stockCount,
      'receipts': Feat.receipts,
      'documents': Feat.documents,
    };
    final map = <String, Rights>{Feat.access: const Rights(view: true)};
    final items = j['items'];
    if (items is List) {
      for (final m in items.whereType<Map>()) {
        final f = v1[m['id']?.toString()];
        if (f == null) continue;
        map[f] = Rights(view: true, create: true, print: true, edit: m['canEdit'] == true, delete: f == Feat.documents);
      }
    }
    // Before the split these pages rode on another permission.
    if (map[Feat.stockLedger] != null) map[Feat.stockAlerts] = const Rights(view: true);
    if (map[Feat.cashSales] != null) map[Feat.quotations] = map[Feat.cashSales]!;
    return MobilePermissions._(true, map);
  }
}
