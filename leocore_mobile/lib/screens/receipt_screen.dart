import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// Confirmation shown after a sales document is saved to the ERP.
///
/// Cash sales are saved as **drafts** (payment is taken later in the full app)
/// and quotations are saved as **Open** — so this screen confirms the saved
/// document and, for quotations, offers the PDF to send.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  /// Server document status → display label. Uses distinct translation keys so
  /// the quotation status "Open" isn't confused with the "Open" action verb.
  static String _statusLabel(BuildContext context, String status) => switch (status) {
        'Draft' => context.tr('Draft'),
        'Open' => context.tr('Open quotation'),
        '' => context.tr('Saved'),
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final doc = app.savedDoc;
    final isQuote = doc != null && doc.expiryDate.isNotEmpty;

    if (doc == null) {
      return Column(
        children: [
          ScreenHeader(title: context.tr('Saved'), onBack: () => app.nav(Screen.home)),
          Expanded(
            child: Center(
              child: Text(context.tr('Nothing saved yet'), style: TextStyle(fontSize: 14, color: lc.mut)),
            ),
          ),
        ],
      );
    }

    Widget row(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(fontSize: strong ? 14 : 12.5, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: strong ? lc.ink : lc.mut)),
              Text(v,
                  style: TextStyle(
                      fontSize: strong ? 15 : 12.5,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                      color: strong ? lc.tprim : lc.ink,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        );

    return Column(
      children: [
        ScreenHeader(
          title: isQuote ? context.tr('Quotation saved') : context.tr('Draft saved'),
          subtitle: doc.number,
          onBack: () => app.nav(Screen.home),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              LcCard(
                shadow: true,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: lc.okbg, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 30, color: lc.ok),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(doc.number,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Pill(
                        _statusLabel(context, doc.status),
                        bg: isQuote ? lc.goldbg : lc.soft,
                        fg: isQuote ? lc.tprim : lc.mut,
                        size: 11.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    row(context.tr('Date'), doc.date),
                    if (isQuote) row(context.tr('Valid until'), doc.expiryDate),
                    Divider(height: 20, color: lc.line),
                    row(context.tr('Subtotal'), Money.fmt(doc.subTotal)),
                    if (doc.discount > 0) row(context.tr('Discount'), Money.fmt(doc.discount)),
                    row(context.tr('VAT'), Money.fmt(doc.vatAmount)),
                    Divider(height: 20, color: lc.line),
                    row(context.tr('Total'), '${Money.fmt(doc.grandTotal)} BHD', strong: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Cash-sale drafts are completed in the full app.
              if (!isQuote)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: lc.mut),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(context.tr('Open this draft in the full app to take payment.'),
                            style: TextStyle(fontSize: 11.5, height: 1.4, color: lc.mut)),
                      ),
                    ],
                  ),
                ),
              if (isQuote) ...[
                PrimaryButton(
                  context.tr('Download PDF'),
                  icon: Icons.download_outlined,
                  onTap: () => app.downloadQuotationPdf(doc.id),
                  busy: app.quotePdfBusy,
                ),
                const SizedBox(height: 10),
                if (app.lastPdfPath != null)
                  OutlineButton2(context.tr('Share PDF'), onTap: app.shareLastPdf),
              ],
              const SizedBox(height: 12),
              OutlineButton2(
                isQuote ? context.tr('New quotation') : context.tr('New cash sale'),
                borderColor: lc.line,
                onTap: isQuote ? app.newQuotation : app.newSale,
              ),
              const SizedBox(height: 10),
              PrimaryButton(context.tr('Done'), onTap: () => app.nav(Screen.home)),
            ],
          ),
        ),
      ],
    );
  }
}
