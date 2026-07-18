import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// 80mm thermal receipt preview. The paper card uses fixed print colors (not
/// theme tokens) because a real receipt is always ink-on-paper.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  static const _paper = Color(0xFFFFFDF7);
  static const _ink = Color(0xFF22201B);
  static const _muted = Color(0xFF5A564C);
  static const _dash = Color(0xFFB9B4A6);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
                title: 'Receipt preview',
                subtitle: '80mm thermal · INV-10497',
                onBack: () => app.nav(Screen.invoice)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(42, 10, 42, 130),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _paper,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 26,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                    child: Column(
                      children: [
                        // Header
                        const Column(
                          children: [
                            LcLogo(size: 26),
                            SizedBox(height: 6),
                            Text('LeoCore Trading W.L.L.',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _ink)),
                            SizedBox(height: 3),
                            Text('Bldg 224, Rd 339, Blk 333 · Manama, Bahrain',
                                style:
                                    TextStyle(fontSize: 10.5, color: _muted)),
                            Text('CR 84921-1 · TRN 220004479200002',
                                style:
                                    TextStyle(fontSize: 10.5, color: _muted)),
                            Text('Tel +973 1729 4400',
                                style:
                                    TextStyle(fontSize: 10.5, color: _muted)),
                          ],
                        ),
                        _dashDivider(),
                        // Meta
                        Column(
                          children: [
                            _metaRow('Invoice', 'INV-10497'),
                            _metaRow('Date', '04 Jul 2026 · 10:42'),
                            _metaRow('Cashier', 'Yousif M. · Van 12'),
                            _metaRow('Payment', app.payments.isEmpty ? '—' : app.payments.map((p) => p.method).toSet().join(', ')),
                          ],
                        ),
                        _dashDivider(),
                        // Lines
                        Column(
                          children: [
                            for (final line in app.cart) ...[
                              Builder(builder: (_) {
                                final p = app.productById(line.pid);
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(p.name,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _ink)),
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            '${line.qty} × ${Money.fmt(p.price)}',
                                            style: const TextStyle(
                                                fontSize: 10.5, color: _muted)),
                                        Text(Money.fmt(p.price * line.qty),
                                            style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: _ink)),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 7),
                            ],
                          ],
                        ),
                        _dashDivider(),
                        // Totals
                        Column(
                          children: [
                            _totalRow('Subtotal', Money.fmt(app.subtotal)),
                            _totalRow('VAT 10%', Money.fmt(app.vat)),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL BHD',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _ink)),
                                Text(Money.fmt(app.total),
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _ink)),
                              ],
                            ),
                            for (final p in app.payments) _totalRow(p.method, Money.fmt(p.amount)),
                            _totalRow('Paid', Money.fmt(app.totalPaid)),
                            _totalRow('Change', Money.fmt(app.change)),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: _dash))),
                          child: Column(
                            children: [
                              CustomPaint(
                                  size: const Size(150, 34),
                                  painter: _BarcodePainter()),
                              const SizedBox(height: 6),
                              const Text(
                                  'شكراً لتسوقكم معنا · Thank you for shopping with us',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: 10, color: _muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
                color: lc.card,
                border: Border(top: BorderSide(color: lc.line))),
            child: Row(
              children: [
                Expanded(
                    flex: 10,
                    child: OutlineButton2('Print',
                        borderColor: lc.line, onTap: () => app.showToast('Receipt printing is coming soon'))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 13,
                    child: PrimaryButton('New sale', onTap: app.newSale)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashDivider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        height: 1,
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _dash))),
      );

  Widget _metaRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 10.5, color: _muted)),
            Text(v, style: const TextStyle(fontSize: 10.5, color: _ink)),
          ],
        ),
      );

  Widget _totalRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 11, color: _muted)),
            Text(v, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      );
}

class _BarcodePainter extends CustomPainter {
  static const List<double> _widths = [
    3,
    1.5,
    4,
    1.5,
    2.5,
    4.5,
    1.5,
    3,
    1.5,
    4,
    2,
    3.5,
    1.5,
    4.5,
    2,
    3,
    1.5,
    4,
    2.5,
    1.5,
    3.5,
    2,
    4,
    1.5,
    3
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF22201B);
    var x = 2.0;
    for (var i = 0; i < _widths.length; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 2, _widths[i], 30), paint);
      }
      x += _widths[i] + 2.5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
