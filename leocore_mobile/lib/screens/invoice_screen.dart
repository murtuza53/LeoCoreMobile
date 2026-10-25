import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import '../widgets/product_picker.dart';

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Cash sale'),
              subtitle: 'INV-10497 · ${context.tr('Walk-in customer')}',
              onBack: app.leaveDoc,
              actions: [
                GestureDetector(
                  onTap: app.openScan,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: lc.goldbg, border: Border.all(color: lc.gold), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.qr_code_scanner, size: 17, color: lc.icon),
                      const SizedBox(width: 7),
                      Text(context.tr('Scan'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: lc.tprim)),
                    ]),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AddItemBar(),
            ),
            Expanded(
              child: app.cart.isEmpty
                  ? _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 260),
                      itemCount: app.cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => DocLineCard(app.cart[i], quote: false),
                    ),
            ),
          ],
        ),
        // Sticky totals + payment panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: lc.card,
              border: Border(top: BorderSide(color: lc.line)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _totalRow(context, context.tr('Subtotal'), Money.fmt(app.subtotal)),
                const SizedBox(height: 10),
                _totalRow(context, context.tr('VAT 10%'), Money.fmt(app.vat)),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: lc.line, style: BorderStyle.solid))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(context.tr('Total'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      MoneyText(app.total, size: 22, unit: 'BHD', color: lc.tprim),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Payment is NOT collected on mobile — the draft is opened in
                // the full app to take payment there.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: lc.mut),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          context.tr('Saved as a draft — payment is taken in the full app.'),
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: lc.mut),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  context.tr('Save as draft'),
                  icon: Icons.save_outlined,
                  onTap: app.saveDraft,
                  busy: app.savingDraft,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(BuildContext context, String label, String value) {
    final lc = context.lc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: lc.mut)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}


class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 200, left: 32, right: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: lc.line),
            const SizedBox(height: 12),
            Text(context.tr('No items yet'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('Search above or scan a barcode to add items.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: lc.mut)),
          ],
        ),
      ),
    );
  }
}
