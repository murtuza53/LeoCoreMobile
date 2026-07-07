import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../screens/count_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/home_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/login_screen.dart';
import '../screens/low_stock_screen.dart';
import '../screens/more_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/products_screen.dart';
import '../screens/receipt_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statement_picker_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/statement_screen.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sheets.dart';

/// Root view: renders the active screen (state-driven), the bottom nav when
/// applicable, any open bottom sheet, and the toast — all stacked exactly like
/// the HTML prototype's single-frame component.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    final body = switch (app.screen) {
      Screen.login => const LoginScreen(),
      Screen.home => const HomeScreen(),
      Screen.products => const ProductsScreen(),
      Screen.product => const ProductDetailScreen(),
      Screen.scan => const ScanScreen(),
      Screen.customers => const CustomersScreen(),
      Screen.customer => const CustomerScreen(),
      Screen.suppliers => const SuppliersScreen(),
      Screen.statementPicker => const StatementPickerScreen(),
      Screen.statement => const StatementScreen(),
      Screen.count => const CountScreen(),
      Screen.low => const LowStockScreen(),
      Screen.invoice => const InvoiceScreen(),
      Screen.receipt => const ReceiptScreen(),
      Screen.reports => const ReportsScreen(),
      Screen.settings => const SettingsScreen(),
      Screen.more => const MoreScreen(),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final handled = app.handleSystemBack();
        if (!handled && app.confirmExit()) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: app.screen == Screen.scan ? const Color(0xFF0E0B0A) : lc.bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: body),
            if (app.showNav)
              const Positioned(left: 0, right: 0, bottom: 0, child: LcBottomNav()),
            if (app.whSheet) const WarehouseSheet(),
            if (app.filterSheet) const FilterSheet(),
            if (app.editSheet) const EditSheet(),
            if (app.toast != null) LcToast(app.toast!),
          ],
        ),
      ),
    );
  }
}
