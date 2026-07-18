import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: app.openWhSheet,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const LcLogo(size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(child: Text(app.companyLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 5),
                              Icon(Icons.keyboard_arrow_down, size: 14, color: lc.mut),
                            ]),
                            Text(app.wh, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: lc.mut)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Stack(
                children: [
                  IconChip(Icons.notifications_none_rounded, fg: lc.ink),
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: lc.bad, shape: BoxShape.circle, border: Border.all(color: lc.card, width: 1.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: lc.goldbg, borderRadius: BorderRadius.circular(12), border: Border.all(color: lc.gold)),
                child: Text(app.userInitials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: lc.tprim)),
              ),
            ],
          ),
        ),
        if (app.offline) const OfflineBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Good morning, ${app.userFirstName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('04 Jul 2026', style: TextStyle(fontSize: 12, color: lc.mut)),
                ],
              ),
              const SizedBox(height: 14),
              // KPI grid 2×2
              Row(children: [
                Expanded(child: _Kpi(label: "Today's sales", value: app.kpiSales, unit: 'BHD', chip: app.kpiSalesChip, chipFg: lc.ok, chipBg: lc.okbg, onTap: app.mReports ? app.goReports : null)),
                const SizedBox(width: 10),
                Expanded(child: _Kpi(label: 'Collections', value: app.kpiCollections, unit: 'BHD', chip: app.kpiCollectionsChip, chipFg: lc.mut, chipBg: lc.soft)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Kpi(label: 'Outstanding AR', value: app.kpiOutstanding, unit: 'BHD', valueColor: lc.prim2, chip: app.kpiArChip, chipFg: lc.bad, chipBg: lc.badbg, onTap: () => app.nav(Screen.customers))),
                const SizedBox(width: 10),
                Expanded(child: _Kpi(label: 'Low stock', value: app.kpiLowStock, unit: 'items', valueColor: lc.warn, chip: app.kpiLowChip, chipFg: lc.warn, chipBg: lc.warnbg, onTap: app.goLow)),
              ]),
              const SizedBox(height: 14),
              _SalesTrendCard(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Workspace'),
                  Pill(app.role.label, bg: lc.goldbg, fg: lc.tprim, size: 11),
                ],
              ),
              const SizedBox(height: 10),
              _WorkspaceGrid(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;
  final String chip;
  final Color chipFg;
  final Color chipBg;
  final VoidCallback? onTap;
  const _Kpi({required this.label, required this.value, required this.unit, this.valueColor, required this.chip, required this.chipFg, required this.chipBg, this.onTap});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return LcCard(
      onTap: onTap,
      shadow: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: lc.mut)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: valueColor ?? lc.ink, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
            ],
          ),
          if (chip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Pill(chip, bg: chipBg, fg: chipFg, size: 11),
          ],
        ],
      ),
    );
  }
}

class _SalesTrendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final app = context.watch<AppState>();
    final live = !app.demoMode;
    final trend = app.homeTrend;
    final hasTrend = trend != null && trend.any((t) => t.total > 0);

    return LcCard(
      shadow: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Sales — last 7 days', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              Text('BHD, net of VAT', style: TextStyle(fontSize: 11.5, color: lc.mut)),
            ],
          ),
          const SizedBox(height: 8),
          if (!live)
            AspectRatio(aspectRatio: 340 / 130, child: CustomPaint(painter: _TrendPainter(lc)))
          else if (hasTrend)
            AspectRatio(aspectRatio: 340 / 130, child: CustomPaint(painter: _LiveTrendPainter(lc, trend)))
          else
            SizedBox(
              height: 96,
              child: Center(
                child: Text('No sales in the last 7 days', style: TextStyle(fontSize: 13, color: lc.mut)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints the real daily-sales trend returned by `/reports/sales`.
class _LiveTrendPainter extends CustomPainter {
  final LcColors lc;
  final List<({String label, double total})> data;
  _LiveTrendPainter(this.lc, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = lc.line..strokeWidth = 1;
    const left = 34.0, right = 10.0, top = 10.0, bottom = 26.0;
    final w = size.width, h = size.height;
    final plotW = w - left - right, plotH = h - top - bottom;
    for (var i = 0; i < 4; i++) {
      final y = top + plotH * i / 3;
      canvas.drawLine(Offset(left, y), Offset(w - right, y), grid);
    }
    final maxV = data.map((e) => e.total).fold<double>(1, (a, b) => b > a ? b : a);
    Offset pt(int i) {
      final x = left + (data.length == 1 ? plotW / 2 : plotW * i / (data.length - 1));
      final y = top + plotH * (1 - (data[i].total / maxV));
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final p = pt(i);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(pt(data.length - 1).dx, top + plotH)
      ..lineTo(pt(0).dx, top + plotH)
      ..close();
    canvas.drawPath(area, Paint()..color = lc.prim.withValues(alpha: 0.09));
    canvas.drawPath(
        path,
        Paint()
          ..color = lc.icon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(pt(data.length - 1), 4.5, Paint()..color = lc.gold);
  }

  @override
  bool shouldRepaint(covariant _LiveTrendPainter old) => old.data != data || old.lc != lc;
}

class _TrendPainter extends CustomPainter {
  final LcColors lc;
  _TrendPainter(this.lc);

  static const _values = [82.0, 64, 90, 52, 70, 38, 34]; // y in 130-space
  static const _labels = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 340;
    final sy = size.height / 130;
    final grid = Paint()..color = lc.line..strokeWidth = 1;
    for (final y in [10.0, 45, 80, 115]) {
      canvas.drawLine(Offset(34 * sx, y * sy), Offset(330 * sx, y * sy), grid);
    }
    final xs = [46.0, 92, 138, 184, 230, 276, 318];
    final path = Path();
    for (var i = 0; i < xs.length; i++) {
      final p = Offset(xs[i] * sx, _values[i] * sy);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    // area fill
    final area = Path.from(path)
      ..lineTo(318 * sx, 115 * sy)
      ..lineTo(46 * sx, 115 * sy)
      ..close();
    canvas.drawPath(area, Paint()..color = lc.prim.withValues(alpha: 0.09));
    canvas.drawPath(path, Paint()..color = lc.icon..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    // last point
    canvas.drawCircle(Offset(318 * sx, 34 * sy), 4.5, Paint()..color = lc.gold);
    canvas.drawCircle(Offset(318 * sx, 34 * sy), 4.5, Paint()..color = lc.card..style = PaintingStyle.stroke..strokeWidth = 2);
    // labels
    final yLabels = ['2.4k', '1.6k', '0.8k', '0'];
    final yPos = [14.0, 49, 84, 119];
    for (var i = 0; i < yLabels.length; i++) {
      _text(canvas, yLabels[i], Offset(28 * sx, yPos[i] * sy), 9, lc.mut, right: true);
    }
    for (var i = 0; i < _labels.length; i++) {
      _text(canvas, _labels[i], Offset(xs[i] * sx, 128 * sy), 9, lc.mut, center: true);
    }
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, {bool right = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (right) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.lc != lc;
}

class _WorkspaceGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final tiles = <(IconData, String, VoidCallback?)>[
      (Icons.inventory_2_outlined, 'Products', () => app.nav(Screen.products)),
      (Icons.people_outline, 'Customers', () => app.nav(Screen.customers)),
      if (app.mSuppliers) (Icons.local_shipping_outlined, 'Suppliers', app.goSuppliers),
      if (app.mSale) (Icons.receipt_long_outlined, 'Cash Sale', () => app.nav(Screen.invoice)),
      if (app.mCount) (Icons.checklist_rounded, 'Stock Count', app.goCount),
      if (app.mCount) (Icons.warning_amber_rounded, 'Low Stock', app.goLow),
      if (app.mReports) (Icons.show_chart, 'Reports', app.goReports),
      (Icons.description_outlined, 'Statements', app.openStatementPicker),
      (Icons.settings_outlined, 'Settings', () => app.nav(Screen.settings)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
      itemCount: tiles.length,
      itemBuilder: (_, i) => _WorkspaceTile(icon: tiles[i].$1, label: tiles[i].$2, onTap: tiles[i].$3),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _WorkspaceTile({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return LcCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: lc.icon),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
