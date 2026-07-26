import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    // Ageing buckets come from the statement response, never hardcoded.
    final aging = app.customerAging;

    Widget bucket(String label, double value, Color fg, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                // Scale down rather than wrap — a wrapped amount reads as a
                // different number (e.g. "1,200.50 / 0").
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.fmt(value),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value < 0 ? lc.ok : lc.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    Widget cell(String s, {int flex = 1, TextAlign align = TextAlign.left, TextStyle? style}) =>
        Expanded(
          flex: flex,
          child: Text(s, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        );

    /// Right-aligned money cell: never wraps, and shows a neutral placeholder
    /// (not a dash) when empty so it can't be mistaken for a minus sign on the
    /// neighbouring balance.
    Widget moneyCell(double? v, {required int flex, TextStyle? style, bool signed = false}) => Expanded(
          flex: flex,
          child: Align(
            alignment: Alignment.centerRight,
            child: v == null
                ? Text('·', style: TextStyle(fontSize: 12, color: lc.mut.withValues(alpha: 0.5)))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      Money.fmt(v),
                      maxLines: 1,
                      softWrap: false,
                      style: (style ?? const TextStyle()).copyWith(
                        color: signed && v < 0 ? lc.bad : style?.color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
          ),
        );

    final head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: lc.mut);

    return Column(
      children: [
        ScreenHeader(
          title: context.tr('Account statement'),
          subtitle: app.statementPartyName,
          onBack: () => app.nav(app.statementReturn),
          actions: [
            IconChip(Icons.download_outlined, fg: lc.ink, onTap: app.downloadStmt, busy: app.statementSharing),
            IconChip(Icons.print_outlined, fg: lc.ink, onTap: app.printStmt, busy: app.statementPrinting),
          ],
        ),
        // As-on date row (tap to pick)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickAsOn(context, app),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(color: lc.card, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: lc.icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('As-on date'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
                        Text(app.statementAsOnLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
            children: [
              Row(children: [
                bucket('0–30d', aging.isNotEmpty ? aging[0] : 0, lc.ok, lc.okbg),
                const SizedBox(width: 8),
                bucket('31–60d', aging.length > 1 ? aging[1] : 0, const Color(0xFF8A6A1F), lc.goldbg),
                const SizedBox(width: 8),
                bucket('61–90d', aging.length > 2 ? aging[2] : 0, lc.warn, lc.warnbg),
                const SizedBox(width: 8),
                bucket('90+d', aging.length > 3 ? aging[3] : 0, lc.bad, lc.badbg),
              ]),
              const SizedBox(height: 12),
              if (app.statementLoading && app.stmtRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4)),
                )
              else
                LcCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lc.line))),
                      child: Row(children: [
                        cell(context.tr('DATE'), flex: 22, style: head),
                        cell(context.tr('DOCUMENT'), flex: 30, style: head),
                        cell(context.tr('DEBIT'), flex: 19, align: TextAlign.right, style: head),
                        cell(context.tr('CREDIT'), flex: 19, align: TextAlign.right, style: head),
                        const SizedBox(width: 10), // gutter before BALANCE
                        cell(context.tr('BALANCE'), flex: 24, align: TextAlign.right, style: head),
                      ]),
                    ),
                    for (final r in app.stmtRows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lc.line))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          cell(r.d, flex: 22, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                          cell(r.doc, flex: 30, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          moneyCell(r.dr,
                              flex: 19,
                              signed: true,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.prim2)),
                          moneyCell(r.cr,
                              flex: 19,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.ok)),
                          // Gutter keeps an empty debit/credit cell from reading
                          // as a minus sign in front of the balance.
                          const SizedBox(width: 10),
                          moneyCell(r.bal,
                              flex: 24,
                              signed: true,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('Closing balance'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${Money.fmt(app.statementClosing)} BHD',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: app.statementClosing < 0 ? lc.bad : lc.prim2,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                app.statementSharing ? context.tr('Preparing PDF…') : context.tr('Download PDF'),
                icon: Icons.download_outlined,
                onTap: app.downloadStmt,
                busy: app.statementSharing,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlineButton2(
                      context.tr('Share'),
                      borderColor: lc.line,
                      onTap: app.shareStmt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlineButton2(
                      context.tr('Print'),
                      onTap: app.printStmt,
                      busy: app.statementPrinting,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAsOn(BuildContext context, AppState app) async {
    final lc = context.lc;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: app.statementAsOn ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (app.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: lc.prim,
            onPrimary: Colors.white,
            surface: lc.card,
            onSurface: lc.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) app.setStatementAsOn(picked);
  }
}
