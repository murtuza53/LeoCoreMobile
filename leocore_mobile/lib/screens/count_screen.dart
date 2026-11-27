import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../api/repositories.dart';
import '../widgets/common.dart';
import '../widgets/paged_list_view.dart';

/// Stock count: the list of UNPROCESSED count sheets on the server, and the open sheet. Sheets are saved to the ERP
/// unprocessed; the web app processes them (adjusts stock). Processed sheets are not shown here.
class CountScreen extends StatelessWidget {
  const CountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return app.countStarted ? const _SheetView() : const _SheetList();
  }
}

// ── List of unprocessed sheets ─────────────────────────────────────────
class _SheetList extends StatelessWidget {
  const _SheetList();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    if (app.countSheets == null && !app.countSheetsLoading && app.countSheetsError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => app.loadCountSheets());
    }
    final sheets = app.countSheets ?? const <CountSheet>[];

    Widget body;
    if (app.countSheetsLoading && app.countSheets == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (app.countSheetsError != null && app.countSheets == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(app.countSheetsError!, textAlign: TextAlign.center, style: TextStyle(color: lc.mut)),
            const SizedBox(height: 12),
            IntrinsicWidth(child: OutlineButton2(context.tr('Retry'), height: 44, onTap: app.loadCountSheets)),
          ]),
        ),
      );
    } else if (sheets.isEmpty) {
      body = RefreshIndicator(
        onRefresh: app.loadCountSheets,
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 36), children: [
          const SizedBox(height: 70),
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: lc.goldbg, borderRadius: BorderRadius.circular(24), border: Border.all(color: lc.gold)),
              child: Icon(Icons.checklist_rounded, size: 38, color: lc.icon),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.tr('No open count sheets'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            context.tr('Start a count sheet for a date and warehouse, scan or search items and enter what you count. Saved sheets wait in the ERP until they are processed from the web app.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.55, color: lc.mut),
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: app.loadCountSheets,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          itemCount: sheets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _SheetCard(sheets[i]),
        ),
      );
    }

    return Stack(children: [
      Column(children: [
        ScreenHeader(
          title: context.tr('Stock count'),
          subtitle: context.tr('Unprocessed count sheets'),
          onBack: () => app.nav(Screen.home),
          actions: [if (app.countSheetsLoading && app.countSheets != null) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))],
        ),
        Expanded(child: body),
      ]),
      if (app.mCountSubmit)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(color: lc.card, border: Border(top: BorderSide(color: lc.line))),
            child: PrimaryButton(context.tr('New count sheet'), icon: Icons.add, onTap: () => app.newCountSheet()),
          ),
        ),
    ]);
  }
}

class _SheetCard extends StatelessWidget {
  final CountSheet s;
  const _SheetCard(this.s);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;
    final where = [s.branchName, s.warehouseName].where((x) => x.isNotEmpty).join(' · ');
    return LcCard(
      onTap: () => app.openCountSheet(s),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.number, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
          _StatusPill(s),
        ]),
        const SizedBox(height: 4),
        Text('${DateFormat('dd MMM yyyy').format(s.date)}${where.isEmpty ? '' : ' · $where'}', style: TextStyle(fontSize: 12.5, color: lc.mut)),
        const SizedBox(height: 2),
        Text(
          [
            '${s.lines} ${context.tr('items counted')}',
            if (s.createdBy.isNotEmpty) '${context.tr('by')} ${s.createdBy}',
            if (s.updatedAt != null) '${context.tr('updated')} ${DateFormat('dd MMM HH:mm').format(s.updatedAt!)}',
          ].join(' · '),
          style: TextStyle(fontSize: 11.5, color: lc.mut),
        ),
        if (s.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.notes, style: const TextStyle(fontSize: 12.5))),
        if (s.failed && s.message.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.message, style: TextStyle(fontSize: 11.5, color: lc.bad))),
      ]),
    );
  }
}

/// Draft = still counting; Unprocessed = counting done, waiting for the web app; Process failed = a web run failed.
class _StatusPill extends StatelessWidget {
  final CountSheet s;
  const _StatusPill(this.s);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    if (s.failed) return Pill(context.tr('Process failed'), bg: lc.badbg, fg: lc.bad, size: 11);
    if (s.ready) return Pill(context.tr('Unprocessed'), bg: lc.okbg, fg: lc.ok, size: 11);
    return Pill(context.tr('Draft'), bg: lc.warnbg, fg: lc.warn, size: 11);
  }
}

// ── The open sheet ─────────────────────────────────────────────────────
class _SheetView extends StatelessWidget {
  const _SheetView();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final s = app.countSheet!;
    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: s.id == 0 ? context.tr('New count sheet') : s.number,
              subtitle: '${DateFormat('dd MMM yyyy').format(s.date)} · ${app.countWarehouseName}',
              onBack: app.closeCountSheet,
              actions: [
                if (app.countDirty)
                  Pill(context.tr('Unsaved'), bg: lc.warnbg, fg: lc.warn, size: 11)
                else if (s.id > 0)
                  _StatusPill(s),
                if (app.mCountSubmit)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) => switch (v) {
                      'edit' => app.newCountSheet(edit: true),
                      'ready' => app.saveCountSheet(status: 'Unprocessed'),
                      'draft' => app.saveCountSheet(status: 'Draft'),
                      _ => app.deleteCountSheet(),
                    },
                    itemBuilder: (_) => [
                      if (!s.ready)
                        PopupMenuItem(value: 'ready', child: Text(context.tr('Counting done - ready to process'))),
                      if (s.ready)
                        PopupMenuItem(value: 'draft', child: Text(context.tr('Back to draft (still counting)'))),
                      PopupMenuItem(value: 'edit', child: Text(context.tr('Date & notes'))),
                      PopupMenuItem(value: 'delete', child: Text(context.tr('Delete sheet'), style: TextStyle(color: lc.bad))),
                    ],
                  ),
              ],
            ),
            Expanded(child: _CountList()),
          ],
        ),
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
                Expanded(
                  child: PrimaryButton(
                    '${context.tr('Save')} (${app.countedLines})',
                    icon: Icons.cloud_upload_outlined,
                    onTap: app.mCountSubmit && (app.countDirty || s.id == 0) ? app.saveCountSheet : null,
                    busy: app.submittingCount,
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

class _CountList extends StatefulWidget {
  @override
  State<_CountList> createState() => _CountListState();
}

class _CountListState extends State<_CountList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final list = app.countList;
    if (!app.countOnlyCounted) list.ensureLoaded();
    // A scan can set the search (to show the scanned item).
    if (_search.text != app.countQuery) {
      _search.value = TextEditingValue(text: app.countQuery, selection: TextSelection.collapsed(offset: app.countQuery.length));
    }

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

    final counted = app.countedRows;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(children: [
            statCard(context.tr('Counted'), '${app.countedLines} ${context.tr('items')}'),
            const SizedBox(width: 8),
            statCard(context.tr('Variances'), '${app.countVar}', color: app.countVar > 0 ? lc.bad : null),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Segmented(
            options: [context.tr('All items'), '${context.tr('Counted')} (${app.countedLines})'],
            selected: app.countOnlyCounted ? 1 : 0,
            onSelect: (i) => app.setCountOnlyCounted(i == 1),
          ),
        ),
        if (!app.countOnlyCounted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchField(hint: context.tr('Search name, code or barcode'), controller: _search, onChanged: app.setCountQuery),
          ),
        Expanded(
          child: app.countOnlyCounted
              ? (counted.isEmpty
                  ? Center(child: Text(context.tr('Nothing counted on this sheet yet'), style: TextStyle(color: lc.mut)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 130),
                      itemCount: counted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _CountRow(counted[i]),
                    ))
              : PagedListView<CountSheetRow>(
                  list: list,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 130),
                  emptyText: 'No matching items',
                  itemBuilder: (_, r) => _CountRow(r),
                ),
        ),
      ],
    );
  }
}

class _CountRow extends StatelessWidget {
  final CountSheetRow r;
  const _CountRow(this.r);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final exp = app.countExpected(r.itemId);
    final cnt = app.countValue(r.itemId);
    final v = cnt == null ? 0 : cnt - exp;
    final ok = v == 0;
    final meta = app.countMeta[r.itemId];
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
                    Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25)),
                    ItemCodes(code: r.code, supplierCode: r.supplierCode, barcode: r.barcode),
                  ],
                ),
              ),
              if (cnt != null) Pill('Δ ${v > 0 ? '+' : ''}$v', bg: ok ? lc.okbg : lc.badbg, fg: ok ? lc.ok : lc.bad, size: 11),
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
              _StepBtn('−', border: lc.line, fg: lc.mut, onTap: () => app.decCount(r.itemId)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _typeQty(context, app, exp),
                child: Container(
                  width: 64,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lc.soft,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: cnt == null ? lc.line : lc.prim),
                  ),
                  child: Text(cnt == null ? '—' : '$cnt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cnt == null ? lc.mut : null)),
                ),
              ),
              const SizedBox(width: 10),
              _StepBtn('+', border: lc.prim, fg: lc.tprim, onTap: () => app.incCount(r.itemId)),
            ],
          ),
          if (cnt != null && meta != null && meta.by.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${context.tr('Counted by')} ${meta.by}${meta.at != null ? ' · ${DateFormat('dd MMM HH:mm').format(meta.at!)}' : ''}',
                style: TextStyle(fontSize: 11, color: lc.mut),
              ),
            ),
        ],
      ),
    );
  }

  /// Type the counted quantity; "Not counted" takes the item off the sheet.
  Future<void> _typeQty(BuildContext context, AppState app, int exp) async {
    final cur = app.countValue(r.itemId);
    final c = TextEditingController(text: cur?.toString() ?? '');
    final res = await showDialog<({int? qty})>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.tr('Counted quantity'), helperText: '${context.tr('Expected')}: $exp'),
          onSubmitted: (v) => Navigator.pop(dctx, (qty: int.tryParse(v.trim()))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, (qty: null)), child: Text(context.tr('Not counted'))),
          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(context.tr('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(dctx, (qty: int.tryParse(c.text.trim()))),
            child: Text(context.tr('Save'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (res == null) return; // cancelled
    // Save with something that isn't a whole number keeps the old value.
    if (res.qty == null && c.text.trim().isNotEmpty && int.tryParse(c.text.trim()) == null) return;
    app.setCount(r.itemId, res.qty);
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
