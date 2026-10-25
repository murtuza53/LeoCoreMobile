import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import 'common.dart';

/// Tappable "Add item" bar for the cash-sale and quotation screens.
class AddItemBar extends StatelessWidget {
  const AddItemBar({super.key});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showProductPicker(context),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: lc.card, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: lc.mut),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                context.tr('Search product by ID, name, brand or category'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: lc.mut),
              ),
            ),
            Icon(Icons.add_circle_outline, size: 20, color: lc.tprim),
          ],
        ),
      ),
    );
  }
}

/// Type-to-search product picker. Tapping a row adds one unit to the document
/// being built (cash sale or quotation); the sheet stays open for more items.
Future<void> showProductPicker(BuildContext context) async {
  final lc = context.lc;
  final app = context.read<AppState>();
  app.openPicker();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: lc.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.8,
        child: Consumer<AppState>(
          builder: (ctx2, s, _) {
            final rows = s.pickProductRows;
            return Column(
              children: [
                const SizedBox(height: 10),
                Center(child: Container(width: 40, height: 4.5, decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchField(
                          hint: context.tr('ID, name, brand or category'),
                          onChanged: s.setPickQuery,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => Navigator.of(ctx2).pop(),
                        child: Text(context.tr('Done'), style: TextStyle(fontWeight: FontWeight.w700, color: lc.tprim)),
                      ),
                    ],
                  ),
                ),
                if (s.pickLoading) LinearProgressIndicator(minHeight: 2, color: lc.prim, backgroundColor: lc.line),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            s.pickLoading ? context.tr('Searching…') : context.tr('No matching products'),
                            style: TextStyle(fontSize: 14, color: lc.mut),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _PickRow(rows[i], qty: s.pickedQty(rows[i].id), onAdd: () => s.addPicked(rows[i])),
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

class _PickRow extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback onAdd;
  const _PickRow(this.product, {required this.qty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final p = product;
    final meta = [p.code, p.brand, p.cat].where((s) => s.isNotEmpty).join(' · ');
    return LcCard(
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          InitialsThumb(p, size: 42, fontSize: 12),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty)
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(Money.fmt(p.price), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Flexible(child: StockBadge(p)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 38),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: qty > 0 ? lc.prim : null,
              border: Border.all(color: lc.prim, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: qty > 0
                ? Text('$qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))
                : Icon(Icons.add, size: 20, color: lc.tprim),
          ),
        ],
      ),
    );
  }
}

/// One line of the cash sale / quotation: product, editable unit price,
/// − qty + stepper and line total. Tap the price to change it manually.
class DocLineCard extends StatelessWidget {
  final CartLine line;
  final bool quote;
  const DocLineCard(this.line, {super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final app = context.read<AppState>();
    final p = app.productById(line.pid);
    final price = app.linePrice(line);
    final manual = line.price != null;
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
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _editPrice(context, app, p, price),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: manual ? lc.goldbg : lc.soft,
                          border: Border.all(color: manual ? lc.gold : lc.line),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(Money.fmt(price),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: manual ? lc.tprim : lc.ink)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 12, color: lc.mut),
                        ]),
                      ),
                      Text(' × ${line.qty}', style: TextStyle(fontSize: 11.5, color: lc.mut)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _MiniStep('−', border: lc.line, fg: lc.mut,
              onTap: () => quote ? app.decQuoteLine(line.pid) : app.decLine(line.pid)),
          SizedBox(width: 24, child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          _MiniStep('+', border: lc.prim, fg: lc.tprim,
              onTap: () => quote ? app.incQuoteLine(line.pid) : app.incLine(line.pid)),
          SizedBox(width: 64, child: Text(Money.fmt(price * line.qty), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _editPrice(BuildContext context, AppState app, Product p, double current) async {
    final lc = context.lc;
    final controller = TextEditingController(text: current.toStringAsFixed(3));
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    String? error;
    // null = cancelled; (price: null) = reset to the list price.
    final res = await showDialog<({double? price})>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setState) {
          void submit() {
            final v = double.tryParse(controller.text.replaceAll(',', '').trim());
            if (v == null || v < 0) {
              setState(() => error = context.tr('Enter a valid price'));
              return;
            }
            Navigator.pop(dctx, (price: v));
          }

          return AlertDialog(
            title: Text(context.tr('Unit price'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: lc.mut)),
                const SizedBox(height: 4),
                Text('${context.tr('List price')}: ${Money.fmt(p.price)}', style: TextStyle(fontSize: 12, color: lc.mut)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(suffixText: 'BHD', errorText: error, isDense: true),
                ),
              ],
            ),
            actions: [
              if (line.price != null)
                TextButton(onPressed: () => Navigator.pop(dctx, (price: null)), child: Text(context.tr('Use list price'))),
              TextButton(onPressed: () => Navigator.pop(dctx), child: Text(context.tr('Cancel'))),
              TextButton(
                onPressed: submit,
                child: Text(context.tr('Apply'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
    if (res == null) return;
    // Typing the list price back in is the same as resetting it.
    final price = res.price == null || res.price == p.price ? null : res.price;
    app.setLinePrice(line.pid, price, quote: quote);
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
