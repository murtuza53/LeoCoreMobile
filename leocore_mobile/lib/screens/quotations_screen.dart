import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../api/repositories.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
String _fmt(DateTime? d) => d == null ? '' : _dateFmt.format(d);

/// Saved quotations, newest first. Tap one to see its lines and totals, and
/// download or share its PDF.
class QuotationsScreen extends StatelessWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final rows = app.quoteHistoryRows;

    return Column(
      children: [
        ScreenHeader(
          title: context.tr('Quotations'),
          subtitle: context.tr('Saved quotations · PDF'),
          onBack: app.closeQuoteHistory,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchField(
            hint: context.tr('Search by number or customer'),
            onChanged: app.setQuoteHistoryQuery,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: lc.prim,
            onRefresh: app.loadQuoteHistory,
            child: rows.isEmpty
                ? ListView(children: [
                    SizedBox(
                      height: 320,
                      child: Center(
                        child: app.quoteHistoryLoading
                            ? CircularProgressIndicator(color: lc.prim)
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  app.quoteHistoryError ??
                                      (app.quoteHistoryQuery.isEmpty
                                          ? context.tr('No quotations yet')
                                          : context.tr('No matching quotations')),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: lc.mut),
                                ),
                              ),
                      ),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: rows.length + (app.quoteHistoryHasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == rows.length) {
                        return Center(
                          child: app.quoteHistoryLoading
                              ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(color: lc.prim))
                              : TextButton(
                                  onPressed: () => app.loadQuoteHistory(more: true),
                                  child: Text(context.tr('Load more'), style: TextStyle(fontWeight: FontWeight.w700, color: lc.tprim)),
                                ),
                        );
                      }
                      return _QuoteRow(rows[i]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  final QuotationSummary q;
  const _QuoteRow(this.q);

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final app = context.watch<AppState>();
    final busy = app.quotePdfId == q.id;
    return LcCard(
      onTap: () => _showDetail(context, q),
      padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(q.number, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  if (q.status.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Pill(context.tr(q.status), bg: lc.soft, fg: lc.mut, size: 10.5),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(q.customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(_fmt(q.date), style: TextStyle(fontSize: 11.5, color: lc.mut)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MoneyText(q.grandTotal, size: 15, unit: q.currency, color: lc.tprim),
          SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: lc.prim))
                : IconButton(
                    tooltip: context.tr('Download PDF'),
                    icon: Icon(Icons.picture_as_pdf_outlined, size: 20, color: lc.icon),
                    onPressed: () => app.downloadSavedQuotationPdf(q.id),
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showDetail(BuildContext context, QuotationSummary q) {
  final lc = context.lc;
  final app = context.read<AppState>();
  final detail = app.loadQuotationDetail(q.id);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: lc.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.8,
      child: FutureBuilder<QuotationDetail?>(
        future: detail,
        builder: (ctx, snap) {
          final d = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(child: Container(width: 40, height: 4.5, decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.number, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(q.customer, style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _fmt(q.date),
                        if (q.expiryDate != null) '${context.tr('Valid until')} ${_fmt(q.expiryDate)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: lc.mut),
                    ),
                  ],
                ),
              ),
              Divider(color: lc.line, height: 20),
              Expanded(
                child: snap.connectionState != ConnectionState.done
                    ? Center(child: CircularProgressIndicator(color: lc.prim))
                    : d == null
                        ? Center(child: Text(context.tr('Could not load the quotation'), style: TextStyle(color: lc.mut)))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                            children: [
                              for (final l in d.lines)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            // unitPrice is excl. VAT; shown rounded for reference.
                                            Text('${_qty(l.qty)} × ${Money.fmt(l.unitPrice)}',
                                                style: TextStyle(fontSize: 11.5, color: lc.mut)),
                                          ],
                                        ),
                                      ),
                                      Text(Money.fmt(l.net), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              Divider(color: lc.line, height: 20),
                              _total(context, context.tr('Subtotal'), d.subTotal),
                              if (d.discount != 0) _total(context, context.tr('Discount'), -d.discount),
                              _total(context, context.tr('VAT'), d.vatAmount),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(context.tr('Total'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  MoneyText(d.head.grandTotal, size: 20, unit: d.head.currency, color: lc.tprim),
                                ],
                              ),
                              if (d.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(d.notes, style: TextStyle(fontSize: 12, color: lc.mut)),
                              ],
                            ],
                          ),
              ),
              Consumer<AppState>(
                builder: (_, s, __) {
                  final busy = s.quotePdfId == q.id;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlineButton2(
                            context.tr('Share'),
                            onTap: busy ? null : () => s.shareQuotationPdf(q),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            context.tr('Download PDF'),
                            icon: Icons.picture_as_pdf_outlined,
                            busy: busy,
                            onTap: () => s.downloadSavedQuotationPdf(q.id),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

Widget _total(BuildContext context, String label, double v) {
  final lc = context.lc;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: lc.mut)),
        Text(Money.fmt(v), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
