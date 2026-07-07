import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final TextEditingController _amount;
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: context.read<AppState>().payAmount);
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    if (!_amountFocus.hasFocus && _amount.text != app.payAmount) {
      _amount.value = TextEditingValue(text: app.payAmount, selection: TextSelection.collapsed(offset: app.payAmount.length));
    }

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: 'Cash sale',
              subtitle: 'INV-10497 · Walk-in customer',
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
                      Text('Scan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: lc.tprim)),
                    ]),
                  ),
                ),
              ],
            ),
            Expanded(
              child: app.cart.isEmpty
                  ? _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 260),
                      itemCount: app.cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final line = app.cart[i];
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
                              _MiniStep('−', border: lc.line, fg: lc.mut, onTap: () => app.decLine(line.pid)),
                              SizedBox(width: 24, child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                              _MiniStep('+', border: lc.prim, fg: lc.tprim, onTap: () => app.incLine(line.pid)),
                              SizedBox(width: 64, child: Text(Money.fmt(p.price * line.qty), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        );
                      },
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
                _totalRow(context, 'Subtotal', Money.fmt(app.subtotal)),
                const SizedBox(height: 10),
                _totalRow(context, 'VAT 10%', Money.fmt(app.vat)),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: lc.line, style: BorderStyle.solid))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      MoneyText(app.total, size: 22, unit: 'BHD', color: lc.tprim),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Existing payment lines
                for (var i = 0; i < app.payments.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(_methodIcon(app.payments[i].method), size: 16, color: lc.icon),
                        const SizedBox(width: 8),
                        Expanded(child: Text(app.payments[i].method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Text(Money.fmt(app.payments[i].amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                        GestureDetector(
                          onTap: () => app.removePayment(i),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 16, color: lc.mut)),
                        ),
                      ],
                    ),
                  ),
                // Method chips
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      for (final m in AppState.paymentMethods) ...[
                        Expanded(child: _MethodChip(m, app.payMethod == m, () => app.setPayMethod(m))),
                        if (m != AppState.paymentMethods.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Amount + add
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: lc.line, width: 1.5)),
                        child: Row(
                          children: [
                            Text('Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _amount,
                                focusNode: _amountFocus,
                                onChanged: app.setPayAmount,
                                onSubmitted: (_) => app.addPayment(),
                                textAlign: TextAlign.right,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: lc.ink),
                                decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, hintText: '0.000'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: app.payRemaining,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: lc.gold, width: 1.5)),
                        child: Text('Balance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lc.tprim)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: app.addPayment,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 44,
                        width: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), color: lc.prim),
                        child: const Icon(Icons.add, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Paid + Balance/Change summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: app.balanceDue > 0 ? lc.soft : lc.okbg, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Paid', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lc.mut)),
                          Text('${Money.fmt(app.totalPaid)} BHD', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(app.balanceDue > 0 ? 'Balance due' : 'Change due',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: app.balanceDue > 0 ? lc.bad : lc.ok)),
                          Text('${Money.fmt(app.balanceDue > 0 ? app.balanceDue : app.change)} BHD',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: app.balanceDue > 0 ? lc.bad : lc.ok)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton('Complete sale · print receipt', onTap: app.completeSale),
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

IconData _methodIcon(String method) {
  if (method.startsWith('Cash')) return Icons.payments_outlined;
  if (method.startsWith('Card')) return Icons.credit_card;
  return Icons.account_balance_outlined;
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _MethodChip(this.label, this.on, this.onTap);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: on ? lc.prim : lc.card,
          border: Border.all(color: on ? lc.prim : lc.line, width: 1.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
        ),
      ),
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
            const Text('Cart is empty', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Scan a barcode or add items from Products.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: lc.mut)),
          ],
        ),
      ),
    );
  }
}
