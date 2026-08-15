import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Print Labels (v1.4.7, gate: MobileLabels). Pick a template, choose items and
/// how many copies of each, then render a print-ready PDF from the server.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});
  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().labelQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final rows = app.labelProductRows;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Print Labels'),
              subtitle: context.tr('Barcode & shelf labels'),
              onBack: () => app.nav(Screen.more),
            ),
            // Template selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.label_outline, size: 18, color: lc.icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: app.labelTemplates.isEmpty
                        ? Text(context.tr('No templates available'), style: TextStyle(fontSize: 13, color: lc.mut))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tpl in app.labelTemplates)
                                GestureDetector(
                                  onTap: () => app.setLabelTemplate(tpl.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: app.labelTemplateId == tpl.id ? lc.prim : lc.card,
                                      border: Border.all(color: app.labelTemplateId == tpl.id ? lc.prim : lc.line),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(tpl.name,
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: app.labelTemplateId == tpl.id ? Colors.white : lc.ink)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchField(
                hint: context.tr('Search name, code or barcode'),
                controller: _search,
                onChanged: app.setLabelQuery,
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(context.tr('No products found'), style: TextStyle(fontSize: 14, color: lc.mut)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 130),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = rows[i];
                        final qty = app.labelQty[p.id] ?? 0;
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
                                    Text(p.barcode.isEmpty ? p.code : p.barcode, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                                  ],
                                ),
                              ),
                              _Stepper(
                                qty: qty,
                                onChanged: (v) => app.setLabelQty(p.id, v),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // Sticky print bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(color: lc.card, border: Border(top: BorderSide(color: lc.line))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    app.labelTotalCopies == 0
                        ? context.tr('Add items to print')
                        : '${app.labelTotalCopies} ${context.tr('labels')} · ${app.labelQty.length} ${context.tr('items')}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lc.mut),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    context.tr('Print PDF'),
                    icon: Icons.print_outlined,
                    onTap: app.printLabels,
                    busy: app.labelsBusy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.qty, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    if (qty == 0) {
      return GestureDetector(
        onTap: () => onChanged(1),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: lc.line, width: 1.5)),
          child: Text(context.tr('Add'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: lc.tprim)),
        ),
      );
    }
    Widget btn(IconData ic, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: lc.line, width: 1.5)),
            child: Icon(ic, size: 16, color: lc.ink),
          ),
        );
    return Row(
      children: [
        btn(Icons.remove, () => onChanged(qty - 1)),
        SizedBox(width: 32, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        btn(Icons.add, () => onChanged(qty + 1)),
      ],
    );
  }
}
