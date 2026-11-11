import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/models/permissions.dart';
import 'package:leocore_mobile/state/app_state.dart';

const _all = {'view': true, 'create': true, 'edit': true, 'delete': true, 'print': true, 'email': true};

MobilePermissions _perms(Map<String, Map<String, bool>> m) =>
    MobilePermissions.fromMenu({'version': 2, 'permissions': {'MobileAccess': {'view': true}, ...m}});

AppState _app(Map<String, Map<String, bool>> m) => AppState()..debugUsePermissions(_perms(m));

List<String> _home(AppState a) => [for (final p in a.homePages) p.homeTitle];
List<String> _more(AppState a) => [for (final p in a.morePages) p.more!];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('full access: Home and More exactly as before', () {
    final a = _app({for (final f in [
      Feat.dashboard, Feat.products, Feat.labels, Feat.customers, Feat.suppliers, Feat.statements, Feat.stockLedger,
      Feat.stockAlerts, Feat.reports, Feat.financeReports, Feat.cashSales, Feat.quotations, Feat.stockCount,
      Feat.receipts, Feat.documents]) f: _all});
    // Previous build (5fe60b5) — screens/home_screen.dart and screens/more_screen.dart.
    expect(_home(a), ['Products', 'Customers', 'Suppliers', 'Cash Sale', 'Stock Count', 'Low Stock', 'Reports', 'Statements']);
    expect(_more(a), ['Cash sales invoice', 'Quotation', 'Saved quotations', 'Stock count', 'Stock alerts', 'Reports',
                      'Business health', 'Print Labels', 'Attach Docs', 'Suppliers']);
    expect(a.mDashboard && a.mReports, isTrue); // KPIs + sales chart
    debugPrint('FULL home=${_home(a)} more=${_more(a)}');
  });

  test('documents only', () {
    final a = _app({Feat.documents: {'view': true, 'edit': true}});
    debugPrint('DOCS home=${_home(a)} more=${_more(a)} pages=${a.pages.length} dash=${a.mDashboard} products=${a.mProducts} customers=${a.mCustomers}');
    expect(_home(a), ['Attach Docs']);
    expect(_more(a), ['Attach Docs']);
  });

  test('products + documents', () {
    final a = _app({Feat.products: {'view': true, 'edit': true}, Feat.documents: {'view': true, 'edit': true}});
    debugPrint('PRODDOCS home=${_home(a)} more=${_more(a)} pages=${a.pages.length} edit=${a.mProductEdit} sale=${a.mSale} countSubmit=${a.mCountSubmit} customers=${a.mCustomers}');
  });

  test('random mix', () {
    final a = _app({
      Feat.dashboard: {'view': true},
      Feat.customers: {'view': true},
      Feat.statements: {'view': true},
      Feat.quotations: {'view': true, 'create': true},
      Feat.stockAlerts: {'view': true},
    });
    debugPrint('RANDOM home=${_home(a)} more=${_more(a)} dash=${a.mDashboard} reports=${a.mReports} products=${a.mProducts} quotePrint=${a.mQuotePrint} hasWh=${a.hasWarehouses}');
  });
}
