import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
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

    Widget bucket(String label, String amount, Color fg, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        );

    Widget cell(String s, {int flex = 1, TextAlign align = TextAlign.left, TextStyle? style}) =>
        Expanded(flex: flex, child: Text(s, textAlign: align, style: style));
    final head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: lc.mut);

    return Column(
      children: [
        ScreenHeader(
          title: 'Account statement',
          subtitle: app.statementPartyName,
          onBack: () => app.nav(app.statementReturn),
          actions: [
            IconChip(Icons.ios_share, fg: lc.ink, onTap: app.shareStmt, busy: app.statementSharing),
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
                        Text('As-on date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
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
                bucket('0–30d', '1,200.500', lc.ok, lc.okbg),
                const SizedBox(width: 8),
                bucket('31–60d', '850.250', const Color(0xFF8A6A1F), lc.goldbg),
                const SizedBox(width: 8),
                bucket('61–90d', '400.000', lc.warn, lc.warnbg),
                const SizedBox(width: 8),
                bucket('90+d', '0.000', lc.bad, lc.badbg),
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
                        cell('DATE', flex: 23, style: head),
                        cell('DOCUMENT', flex: 32, style: head),
                        cell('DEBIT', flex: 20, align: TextAlign.right, style: head),
                        cell('CREDIT', flex: 20, align: TextAlign.right, style: head),
                        cell('BALANCE', flex: 21, align: TextAlign.right, style: head),
                      ]),
                    ),
                    for (final r in app.stmtRows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lc.line))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          cell(r.d, flex: 23, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                          cell(r.doc, flex: 32, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          cell(r.dr == null ? '—' : Money.fmt(r.dr!), flex: 20, align: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.prim2)),
                          cell(r.cr == null ? '—' : Money.fmt(r.cr!), flex: 20, align: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.ok)),
                          cell(Money.fmt(r.bal), flex: 21, align: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Closing balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('${MockData.money(app.statementClosing)} BHD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: lc.prim2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                app.statementSharing ? 'Preparing PDF…' : 'Share PDF via WhatsApp',
                icon: Icons.ios_share,
                onTap: app.shareStmt,
                busy: app.statementSharing,
              ),
              const SizedBox(height: 10),
              OutlineButton2(
                'Print statement',
                onTap: app.printStmt,
                busy: app.statementPrinting,
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
