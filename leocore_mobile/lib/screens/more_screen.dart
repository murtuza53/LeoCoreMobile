import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final items = <(IconData, String, String, VoidCallback)>[
      if (app.mSale) (Icons.receipt_long_outlined, context.tr('Cash sales invoice'), context.tr('Scan items, save as draft'), () => app.newSale()),
      if (app.mSale) (Icons.request_quote_outlined, context.tr('Quotation'), context.tr('Save & send as PDF'), () => app.newQuotation()),
      if (app.mCount) (Icons.checklist_rounded, context.tr('Stock count'), context.tr('Expected vs counted, variance'), app.goCount),
      if (app.mCount) (Icons.warning_amber_rounded, context.tr('Stock alerts'), context.tr('Low stock & dead stock'), app.goLow),
      if (app.mReports) (Icons.show_chart, context.tr('Reports'), context.tr('Sales & purchases, top lists'), app.goReports),
      if (app.mAnalytics || app.mFinance) (Icons.insights_outlined, context.tr('Business health'), context.tr('Aging, cash, margin, trends'), app.openManagerReports),
      if (app.mLabels) (Icons.qr_code_2_outlined, context.tr('Print Labels'), context.tr('Barcode & shelf labels'), app.openLabels),
      if (app.mSuppliers) (Icons.local_shipping_outlined, context.tr('Suppliers'), context.tr('Directory & account statements'), app.goSuppliers),
      (Icons.settings_outlined, context.tr('Settings'), context.tr('Language, theme, devices, role'), () => app.nav(Screen.settings)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
          child: Text(context.tr('More'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            children: [
              for (final it in items) ...[
                _MoreRow(icon: it.$1, title: it.$2, subtitle: it.$3, onTap: it.$4),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              _SignOutButton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;
    return GestureDetector(
      onTap: app.doLogout,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: lc.bad, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, size: 18, color: lc.bad),
            const SizedBox(width: 8),
            Text(context.tr('Sign out'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: lc.bad)),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MoreRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return LcCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: lc.icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: lc.mut)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 15, color: lc.mut),
        ],
      ),
    );
  }
}
