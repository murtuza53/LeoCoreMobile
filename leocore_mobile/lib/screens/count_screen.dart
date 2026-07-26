import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class CountScreen extends StatelessWidget {
  const CountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Stock count'),
              subtitle: 'Main WH · Tubli',
              onBack: () => app.nav(Screen.home),
              actions: [
                if (app.countStarted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(color: lc.okbg, borderRadius: BorderRadius.circular(99)),
                    child: Text('● Session CNT-0042', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: lc.ok)),
                  ),
              ],
            ),
            if (!app.countStarted)
              Expanded(child: _StartPane(onStart: app.startCount))
            else
              Expanded(child: _CountList()),
          ],
        ),
        if (app.countStarted)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(color: lc.card, border: Border(top: BorderSide(color: lc.line))),
              child: Row(
                children: [
                  IconChip(Icons.qr_code_scanner, size: 52, fg: lc.gold, border: Border.all(color: lc.gold, width: 1.5), onTap: app.openScan),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(context.tr('Submit count'), onTap: app.submitCount)),
                ],
              ),
            ),
          ),
        if (app.countSubmitted) _CountDoneDialog(),
      ],
    );
  }
}

class _StartPane extends StatelessWidget {
  final VoidCallback onStart;
  const _StartPane({required this.onStart});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: lc.goldbg, borderRadius: BorderRadius.circular(24), border: Border.all(color: lc.gold)),
              child: Icon(Icons.checklist_rounded, size: 38, color: lc.icon),
            ),
            const SizedBox(height: 16),
            Text(context.tr('Start a count session'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(context.tr('Scan items with the barcode button — expected quantities load from the selected warehouse and variances are highlighted as you go.'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.55, color: lc.mut)),
            const SizedBox(height: 16),
            IntrinsicWidth(child: PrimaryButton(context.tr('Start session'), onTap: onStart)),
          ],
        ),
      ),
    );
  }
}

class _CountList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final products = app.countProducts;

    Widget statCard(String label, String value, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: lc.card, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: lc.mut)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(children: [
            statCard(context.tr('Lines'), '${products.length} ${context.tr('lines')}'),
            const SizedBox(width: 8),
            statCard(context.tr('Variances'), '${app.countVar} ${context.tr('variance')}', color: lc.bad),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 130),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = products[i];
              final exp = app.countExpected(p.id);
              final cnt = app.countValue(p.id);
              final v = cnt - exp;
              final ok = v == 0;
              return LcCard(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              Text(p.code, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                            ],
                          ),
                        ),
                        Pill('Δ ${v > 0 ? '+' : ''}$v', bg: ok ? lc.okbg : lc.badbg, fg: ok ? lc.ok : lc.bad, size: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('Expected'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: lc.mut)),
                              Text('$exp', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        _StepBtn('−', border: lc.line, fg: lc.mut, onTap: () => app.decCount(p.id)),
                        const SizedBox(width: 10),
                        Container(
                          width: 56,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(11)),
                          child: Text('$cnt', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        _StepBtn('+', border: lc.prim, fg: lc.tprim, onTap: () => app.incCount(p.id)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final Color border;
  final Color fg;
  final VoidCallback onTap;
  const _StepBtn(this.label, {required this.border, required this.fg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: border, width: 1.5)),
        child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _CountDoneDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(color: lc.card, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: lc.okbg, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 28, color: lc.ok),
              ),
              const SizedBox(height: 12),
              Text(context.tr('Count submitted'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Session CNT-0042 · 4 ${context.tr('lines')} · ${app.countVar} ${context.tr('variance sent for approval.')}',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: lc.mut)),
              const SizedBox(height: 16),
              IntrinsicWidth(child: PrimaryButton(context.tr('Done'), height: 46, onTap: app.closeCountDone)),
            ],
          ),
        ),
      ),
    );
  }
}
