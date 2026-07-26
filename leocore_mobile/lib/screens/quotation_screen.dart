import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// Quotation builder — pick a customer, add items (scan or from Products),
/// then save. On save the server prices the document and returns its number;
/// the PDF is downloaded straight away so it can be sent to the customer.
class QuotationScreen extends StatelessWidget {
  const QuotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final customer = app.quoteCustomer;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Quotation'),
              subtitle: context.tr('Save & send as PDF'),
              onBack: () => app.nav(Screen.home),
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
            // Customer selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickCustomer(context, app),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: lc.card,
                    border: Border.all(color: customer == null ? lc.gold : lc.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: lc.icon),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Customer'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
                            Text(
                              customer?.name ?? context.tr('Choose a customer'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: customer == null ? lc.mut : lc.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: lc.mut),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: app.quoteLines.isEmpty
                  ? _EmptyLines()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 210),
                      itemCount: app.quoteLines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final line = app.quoteLines[i];
                        final p = app.productById(line.pid);
                        return LcCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              InitialsThumb(p, size: 42, fontSize: 12),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('${Money.fmt(p.price)} × ${line.qty}', style: TextStyle(fontSize: 11.5, color: lc.mut)),
                                  ],
                                ),
                              ),
                              _MiniStep('−', border: lc.line, fg: lc.mut, onTap: () => app.decQuoteLine(line.pid)),
                              SizedBox(width: 24, child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                              _MiniStep('+', border: lc.prim, fg: lc.tprim, onTap: () => app.incQuoteLine(line.pid)),
                              SizedBox(width: 64, child: Text(Money.fmt(p.price * line.qty), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // Sticky totals + save
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
                _totalRow(context, context.tr('Subtotal'), Money.fmt(app.quoteSubtotal)),
                const SizedBox(height: 10),
                _totalRow(context, context.tr('VAT 10%'), Money.fmt(app.quoteVat)),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: lc.line))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(context.tr('Total'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      MoneyText(app.quoteTotal, size: 22, unit: 'BHD', color: lc.tprim),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(context.tr('Final pricing is confirmed by the server on save.'),
                    style: TextStyle(fontSize: 11, color: lc.mut)),
                const SizedBox(height: 10),
                PrimaryButton(
                  context.tr('Save & download PDF'),
                  icon: Icons.picture_as_pdf_outlined,
                  onTap: app.saveQuotation,
                  busy: app.savingQuote || app.quotePdfBusy,
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

  /// Type-to-search customer picker.
  Future<void> _pickCustomer(BuildContext context, AppState app) async {
    final lc = context.lc;
    final controller = TextEditingController(text: app.quoteCustomerQuery);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: lc.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: Consumer<AppState>(
            builder: (ctx2, s, _) {
              final rows = s.quoteCustomerRows;
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Center(child: Container(width: 40, height: 4.5, decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SearchField(
                      hint: context.tr('Search customer by name or area'),
                      controller: controller,
                      onChanged: s.setQuoteCustomerQuery,
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(context.tr('No matching customers'), style: TextStyle(fontSize: 14, color: lc.mut)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final c = rows[i];
                              return LcCard(
                                onTap: () {
                                  s.pickQuoteCustomer(c.id);
                                  Navigator.of(ctx2).pop();
                                },
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: lc.goldbg, shape: BoxShape.circle, border: Border.all(color: lc.gold)),
                                      child: Text(MockData.initials(c.name), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.tprim)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                          if (c.area.isNotEmpty) Text(c.area, style: TextStyle(fontSize: 12, color: lc.mut)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, size: 18, color: lc.mut),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  final String label;
  final Color border;
  final Color fg;
  final VoidCallback onTap;
  const _MiniStep(this.label, {required this.border, required this.fg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: border, width: 1.5)),
        child: Text(label, style: TextStyle(fontSize: 17, color: fg)),
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 160, left: 32, right: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.request_quote_outlined, size: 48, color: lc.line),
            const SizedBox(height: 12),
            Text(context.tr('No items yet'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('Scan a barcode or add items from Products.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: lc.mut)),
          ],
        ),
      ),
    );
  }
}
