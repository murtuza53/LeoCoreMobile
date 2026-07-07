import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/repositories.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class LowStockScreen extends StatelessWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final demo = app.demoMode;

    final lowCount = demo ? app.lowRows.length : (app.lowStockRows?.length ?? app.kpis?.lowStock ?? 0);
    final deadCount = demo ? MockData.deadRows.length : (app.deadStockRows?.length ?? 0);

    final loading = !demo && app.stockAlertsLoading;

    return Column(
      children: [
        ScreenHeader(title: 'Stock alerts', onBack: () => app.nav(Screen.home)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Segmented(
            options: ['Low stock · $lowCount', 'Dead stock · $deadCount'],
            selected: app.stockTab == 'low' ? 0 : 1,
            onSelect: (i) => app.pickStockTab(i == 0 ? 'low' : 'dead'),
          ),
        ),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4))
              : app.stockTab == 'low'
                  ? _lowList(context, app, demo)
                  : _deadList(context, app, demo),
        ),
      ],
    );
  }

  Widget _lowList(BuildContext context, AppState app, bool demo) {
    final lc = context.lc;
    if (!demo) {
      final rows = app.lowStockRows ?? const <StockRowData>[];
      if (rows.isEmpty) return _empty(context, 'No low-stock items');
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 60),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = rows[i];
          final (sev, sevFg) = r.onHand == 0 ? ('Critical', lc.bad) : r.onHand <= 10 ? ('High', lc.warn) : ('Medium', lc.gold);
          final (badge, bBg, bFg) = r.onHand == 0
              ? ('Out of stock', lc.badbg, lc.bad)
              : ('Low · ${r.onHand}', lc.warnbg, lc.warn);
          return LcCard(
            onTap: () => app.openProduct(r.id),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                _NameThumb(r.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(r.code, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('● $sev', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sevFg)),
                    const SizedBox(height: 4),
                    Pill(badge, bg: bBg, fg: bFg, size: 11),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
    // Demo
    final low = app.lowRows;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 60),
      itemCount: low.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = low[i];
        final (sev, sevFg) = p.stock == 0 ? ('Critical', lc.bad) : p.stock <= 10 ? ('High', lc.warn) : ('Medium', lc.gold);
        final reorder = p.stock == 0 ? 48 : 24;
        return LcCard(
          onTap: () => app.openProduct(p.id),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              InitialsThumb(p, size: 46, fontSize: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${p.code} · reorder $reorder pcs', style: TextStyle(fontSize: 11.5, color: lc.mut)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('● $sev', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sevFg)),
                  const SizedBox(height: 4),
                  StockBadge(p, size: 11),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _deadList(BuildContext context, AppState app, bool demo) {
    final lc = context.lc;
    if (!demo) {
      final rows = app.deadStockRows ?? const <StockRowData>[];
      if (rows.isEmpty) return _empty(context, 'No dead stock');
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 60),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = rows[i];
          return LcCard(
            onTap: () => app.openProduct(r.id),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.hourglass_empty, size: 20, color: lc.mut),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${r.code} · ${r.onHand} pcs on hand', style: TextStyle(fontSize: 11.5, color: lc.mut)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (r.daysIdle > 0)
                  Text('${r.daysIdle} days idle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.bad)),
              ],
            ),
          );
        },
      );
    }
    // Demo
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 60),
      itemCount: MockData.deadRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = MockData.deadRows[i];
        return LcCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.hourglass_empty, size: 20, color: lc.mut),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${d.code} · ${d.qty} pcs on hand', style: TextStyle(fontSize: 11.5, color: lc.mut)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${d.days} days idle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lc.bad)),
                  const SizedBox(height: 4),
                  Text('${MockData.money(d.val)} BHD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.mut)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext context, String msg) =>
      Center(child: Text(msg, style: TextStyle(fontSize: 14, color: context.lc.mut)));
}

/// Colored thumbnail with initials for API stock rows (no category available).
class _NameThumb extends StatelessWidget {
  final String name;
  const _NameThumb(this.name);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: lc.prim, borderRadius: BorderRadius.circular(11)),
      child: Text(MockData.initials(name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}
