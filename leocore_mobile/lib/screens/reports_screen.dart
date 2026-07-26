import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/repositories.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _ranges = [('today', 'Today'), ('7d', 'Last 7 days'), ('30d', 'Last 30 days'), ('custom', '01 Jan – 04 Jul ▾')];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    return Column(
      children: [
        ScreenHeader(
          title: context.tr('Reports'),
          onBack: () => app.nav(Screen.home),
          actions: [IconChip(Icons.ios_share, fg: lc.ink, onTap: () => app.showToast(context.tr('Report export is coming soon')))],
        ),
        // Range chips
        SizedBox(
          height: 36 + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            itemCount: _ranges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final on = app.reportRange == _ranges[i].$1;
              return GestureDetector(
                onTap: () => app.pickRange(_ranges[i].$1),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? lc.prim : lc.card, border: Border.all(color: on ? lc.prim : lc.line), borderRadius: BorderRadius.circular(99)),
                  child: Text(context.tr(_ranges[i].$2), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: !app.demoMode
              ? _LiveReports(app: app)
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 60),
            children: [
              LcCard(
                shadow: true,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('Sales vs Purchases'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Row(children: [
                          _legend(lc.prim, context.tr('Sales')),
                          const SizedBox(width: 12),
                          _legend(lc.gold, context.tr('Purchases')),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AspectRatio(aspectRatio: 340 / 150, child: CustomPaint(painter: _BarsPainter(lc))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _stat(context, context.tr('Net sales'), '41,208.500', '▲ 8.2%', lc.ok),
                const SizedBox(width: 10),
                _stat(context, context.tr('Purchases'), '27,940.000', '▲ 11.6%', lc.bad),
                const SizedBox(width: 10),
                _stat(context, context.tr('Margin'), '32.2%', '▲ 0.4pt', lc.ok),
              ]),
              const SizedBox(height: 12),
              LcCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(context.tr('Top customers')),
                    const SizedBox(height: 11),
                    _rankBar(context, 1, 'Gulf Mart WLL', 1.0, '9,412.000'),
                    _rankBar(context, 2, 'Al Jazira Supermarket', 0.74, '6,980.250'),
                    _rankBar(context, 3, 'Bahrain Pearl Markets', 0.58, '5,455.500'),
                    _rankBar(context, 4, 'Sitra Foodstuff Est.', 0.41, '3,860.000', last: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LcCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(context.tr('Top items')),
                    const SizedBox(height: 11),
                    _itemRow(context, 1, 'Mahmood Basmati Rice 5kg', '612 pcs', '3,029.400'),
                    _itemRow(context, 2, 'Almarai Full Fat Milk 2L', '1,840 pcs', '2,300.000'),
                    _itemRow(context, 3, 'Lipton Yellow Label 200s', '486 pcs', '1,385.100', last: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }

  Widget _stat(BuildContext context, String label, String value, String delta, Color deltaColor) {
    final lc = context.lc;
    return Expanded(
      child: LcCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: lc.mut)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
            ),
            const SizedBox(height: 4),
            Text(delta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deltaColor)),
          ],
        ),
      ),
    );
  }

  Widget _rankBar(BuildContext context, int rank, String name, double frac, String amount, {bool last = false}) {
    final lc = context.lc;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        children: [
          SizedBox(width: 16, child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.gold))),
          const SizedBox(width: 10),
          Expanded(flex: 10, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(width: 10),
          Expanded(flex: 12, child: BarTrack(fraction: frac, color: lc.prim, height: 7)),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(amount, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, int rank, String name, String qty, String amount, {bool last = false}) {
    final lc = context.lc;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        children: [
          SizedBox(width: 16, child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.gold))),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(qty, style: TextStyle(fontSize: 12, color: lc.mut)),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: Text(amount, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final LcColors lc;
  _BarsPainter(this.lc);

  // (salesY, purchY) top coordinates in 150-space; bars end at y=132.
  static const _bars = [(62.0, 86.0), (48, 78), (70, 92), (38, 72), (55, 84), (26, 66)];
  static const _labels = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
  static const _groupX = [48.0, 96, 144, 192, 240, 288];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 340;
    final sy = size.height / 150;
    final grid = Paint()..color = lc.line..strokeWidth = 1;
    for (final y in [12.0, 52, 92, 132]) {
      canvas.drawLine(Offset(36 * sx, y * sy), Offset(332 * sx, y * sy), grid);
    }
    final salesPaint = Paint()..color = lc.prim;
    final purchPaint = Paint()..color = lc.gold;
    for (var i = 0; i < _bars.length; i++) {
      final gx = _groupX[i];
      final s = _bars[i].$1, p = _bars[i].$2;
      _bar(canvas, Rect.fromLTRB(gx * sx, s * sy, (gx + 14) * sx, 132 * sy), salesPaint);
      _bar(canvas, Rect.fromLTRB((gx + 17) * sx, p * sy, (gx + 31) * sx, 132 * sy), purchPaint);
      _text(canvas, _labels[i], Offset((gx + 15) * sx, 146 * sy), lc.mut);
    }
    final yLabels = ['45k', '30k', '15k', '0'];
    final yPos = [16.0, 56, 96, 136];
    for (var i = 0; i < yLabels.length; i++) {
      _text(canvas, yLabels[i], Offset(30 * sx, yPos[i] * sy), lc.mut, right: true);
    }
  }

  void _bar(Canvas canvas, Rect r, Paint paint) {
    canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)), paint);
  }

  void _text(Canvas canvas, String s, Offset at, Color color, {bool right = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: color)), textDirection: TextDirection.ltr)..layout();
    var dx = at.dx - (right ? tp.width : tp.width / 2);
    tp.paint(canvas, Offset(dx, at.dy - tp.height));
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) => oldDelegate.lc != lc;
}

/// Live reports body — sales/purchase totals and top customers/suppliers.
class _LiveReports extends StatelessWidget {
  final AppState app;
  const _LiveReports({required this.app});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    if (app.reportsLoading && app.salesRep == null) {
      return Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4));
    }
    final sales = app.salesRep ?? const ReportData();
    final purch = app.purchaseRep ?? const ReportData();
    final gross = sales.total - purch.total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 60),
      children: [
        Row(children: [
          _stat(context, context.tr('Net sales'), sales.total, lc.ink),
          const SizedBox(width: 10),
          _stat(context, context.tr('Purchases'), purch.total, lc.ink),
          const SizedBox(width: 10),
          _stat(context, context.tr('Gross'), gross, gross >= 0 ? lc.ok : lc.bad),
        ]),
        const SizedBox(height: 12),
        _rankCard(context, context.tr('Top customers'), sales.top),
        const SizedBox(height: 12),
        _rankCard(context, context.tr('Top suppliers'), purch.top),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, double value, Color color) {
    final lc = context.lc;
    return Expanded(
      child: LcCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: lc.mut)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(Money.fmt(value), maxLines: 1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankCard(BuildContext context, String title, List<({String name, double total})> rows) {
    final lc = context.lc;
    if (rows.isEmpty) {
      return LcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(title),
            const SizedBox(height: 12),
            Text(context.tr('No activity in this period'), style: TextStyle(fontSize: 13, color: lc.mut)),
          ],
        ),
      );
    }
    final max = rows.fold<double>(1, (a, e) => e.total > a ? e.total : a);
    return LcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          const SizedBox(height: 11),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 11),
              child: Row(
                children: [
                  SizedBox(width: 16, child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.gold))),
                  const SizedBox(width: 10),
                  Expanded(flex: 10, child: Text(rows[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 10),
                  Expanded(flex: 10, child: BarTrack(fraction: rows[i].total / max, color: lc.prim, height: 7)),
                  const SizedBox(width: 10),
                  SizedBox(width: 78, child: Text(Money.fmt(rows[i].total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
