import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// "Business Health" — the v1.4.5 manager reports, gated by RBAC:
/// finance cards need `MobileFinanceReports`, analytics need `MobileReports`.
class ManagerReportsScreen extends StatelessWidget {
  const ManagerReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final noAccess = !app.mFinance && !app.mAnalytics;

    return Column(
      children: [
        ScreenHeader(
          title: context.tr('Business health'),
          subtitle: app.reportRangeLabel,
          onBack: () => app.nav(Screen.more),
          actions: [
            IconChip(Icons.date_range, fg: lc.ink, onTap: () => _pickRange(context, app)),
          ],
        ),
        if (app.reportsBusy)
          LinearProgressIndicator(minHeight: 2, color: lc.prim, backgroundColor: lc.line),
        Expanded(
          child: noAccess
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(context.tr('Your role does not have access to reports.'),
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: lc.mut)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 60),
                  children: [
                    if (app.mFinance) ...[
                      SectionLabel(context.tr('Cash flow')),
                      const SizedBox(height: 10),
                      if (app.agingRep != null) _AgingCard(),
                      if (app.cashRep != null) _CashCard(),
                    ],
                    if (app.mAnalytics) ...[
                      const SizedBox(height: 4),
                      SectionLabel(context.tr('Performance')),
                      const SizedBox(height: 10),
                      if (app.trendRep != null) _TrendCard(),
                      if (app.mFinance && app.marginRep != null) _MarginCard(),
                      if (app.collectionsRep != null) _CollectionsCard(),
                      if (app.topItemsRep != null) _TopItemsCard(),
                      if (app.categoryRep != null) _CategoryCard(),
                      if (app.salesmanRep != null) _SalesmanCard(),
                    ] else if (app.mFinance && app.marginRep != null) ...[
                      const SizedBox(height: 4),
                      SectionLabel(context.tr('Performance')),
                      const SizedBox(height: 10),
                      _MarginCard(),
                    ],
                    if (app.mFinance) ...[
                      const SizedBox(height: 4),
                      SectionLabel(context.tr('Compliance & inventory')),
                      const SizedBox(height: 10),
                      if (app.vatRep != null) _VatCard(),
                      if (app.valuationRep != null) _ValuationCard(),
                    ],
                    if (!app.reportsBusy && _allEmpty(app))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text(context.tr('No report data for this period.'), style: TextStyle(fontSize: 13.5, color: lc.mut))),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static bool _allEmpty(AppState a) =>
      a.agingRep == null &&
      a.cashRep == null &&
      a.trendRep == null &&
      a.marginRep == null &&
      a.collectionsRep == null &&
      a.topItemsRep == null &&
      a.categoryRep == null &&
      a.salesmanRep == null &&
      a.vatRep == null &&
      a.valuationRep == null;

  Future<void> _pickRange(BuildContext context, AppState app) async {
    final lc = context.lc;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      initialDateRange: DateTimeRange(start: app.reportFrom, end: app.reportTo),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (app.isDark ? const ColorScheme.dark() : const ColorScheme.light())
              .copyWith(primary: lc.prim, onPrimary: Colors.white, surface: lc.card, onSurface: lc.ink),
        ),
        child: child!,
      ),
    );
    if (picked != null) app.setReportRange(picked.start, picked.end);
  }
}

// ── card scaffolding ─────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _kv(BuildContext c, String k, String v, {Color? color, bool big = false}) {
  final lc = c.lc;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(fontSize: big ? 13.5 : 12.5, fontWeight: big ? FontWeight.w700 : FontWeight.w500, color: big ? lc.ink : lc.mut)),
        Text(v,
            style: TextStyle(
                fontSize: big ? 15 : 12.5,
                fontWeight: big ? FontWeight.w700 : FontWeight.w600,
                color: color ?? (big ? lc.tprim : lc.ink),
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    ),
  );
}

class _AgingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.agingRep!;
    final labels = ['0–30d', '31–60d', '61–90d', '91–180d', '180d+'];
    final colors = [lc.ok, const Color(0xFF8A6A1F), lc.warn, lc.bad, lc.bad];
    return _Card(
      title: context.tr('Receivables aging'),
      trailing: Text('${Money.fmt(r.total)} BHD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lc.tprim)),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < r.buckets.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Text(Money.fmt(r.buckets[i]),
                          maxLines: 1,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r.buckets[i] < 0 ? lc.ok : lc.ink)),
                      const SizedBox(height: 3),
                      Text(labels[i], style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: colors[i])),
                    ],
                  ),
                ),
                if (i != r.buckets.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          if (r.topDebtors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: lc.line),
            const SizedBox(height: 8),
            for (final d in r.topDebtors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    if (d.oldestDays > 0) ...[
                      Text('${d.oldestDays}d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.oldestDays > 90 ? lc.bad : lc.mut)),
                      const SizedBox(width: 10),
                    ],
                    Text(Money.fmt(d.outstanding), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.cashRep!;
    return _Card(
      title: context.tr('Cash position'),
      child: Column(
        children: [
          for (final a in r.accounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(a.type.toLowerCase().contains('cash') ? Icons.payments_outlined : Icons.account_balance_outlined, size: 16, color: lc.icon),
                const SizedBox(width: 9),
                Expanded(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                Text(Money.fmt(a.balance), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          Divider(height: 18, color: lc.line),
          _kv(context, context.tr('Cash'), Money.fmt(r.totalCash)),
          _kv(context, context.tr('Bank'), Money.fmt(r.totalBank)),
          _kv(context, context.tr('Total'), '${Money.fmt(r.totalCash + r.totalBank)} BHD', big: true),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.trendRep!;
    final maxV = r.points.fold<double>(1, (a, p) => p.sales > a ? p.sales : a);
    return _Card(
      title: context.tr('Sales trend'),
      trailing: Segmented(
        options: [context.tr('Day'), context.tr('Week'), context.tr('Month')],
        selected: r.groupBy == 'week' ? 1 : (r.groupBy == 'month' ? 2 : 0),
        onSelect: (i) => app.setTrendGroupBy(['day', 'week', 'month'][i]),
        height: 30,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in r.points)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: (76 * (p.sales / maxV)).clamp(2, 76),
                          decoration: BoxDecoration(color: lc.prim, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                        ),
                        const SizedBox(height: 4),
                        Text(p.label.length > 6 ? p.label.substring(p.label.length - 5) : p.label,
                            maxLines: 1, style: TextStyle(fontSize: 8.5, color: lc.mut)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _kv(context, context.tr('Total'), '${Money.fmt(r.total)} BHD', big: true),
          _kv(context, context.tr('Average / day'), Money.fmt(r.avgPerDay)),
        ],
      ),
    );
  }
}

class _MarginCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.marginRep!;
    return _Card(
      title: context.tr('Gross margin'),
      trailing: Pill('${r.marginPct.toStringAsFixed(1)}%', bg: lc.okbg, fg: lc.ok, size: 11.5),
      child: Column(
        children: [
          _kv(context, context.tr('Revenue'), Money.fmt(r.revenue)),
          _kv(context, context.tr('Cost'), Money.fmt(r.cost)),
          _kv(context, context.tr('Gross profit'), '${Money.fmt(r.grossProfit)} BHD', big: true, color: lc.ok),
          if (r.byCategory.isNotEmpty) ...[
            Divider(height: 18, color: lc.line),
            for (final c in r.byCategory.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: lc.mut))),
                  Text(Money.fmt(c.margin), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _CollectionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.collectionsRep!;
    return _Card(
      title: context.tr('Collections'),
      trailing: Text('${Money.fmt(r.total)} BHD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lc.tprim)),
      child: Column(
        children: [
          for (final m in r.byMethod) _kv(context, m.label, Money.fmt(m.amount)),
          if (r.count > 0) ...[
            Divider(height: 16, color: lc.line),
            _kv(context, context.tr('Receipts'), '${r.count}'),
          ],
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final String title;
  final List<({String name, String sub, double value})> rows;
  const _RankCard(this.title, this.rows);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final maxV = rows.fold<double>(1, (a, r) => r.value > a ? r.value : a);
    return _Card(
      title: title,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
              child: Row(children: [
                SizedBox(width: 14, child: Text('${i + 1}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: lc.gold))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      if (rows[i].sub.isNotEmpty) Text(rows[i].sub, style: TextStyle(fontSize: 10.5, color: lc.mut)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 8, child: BarTrack(fraction: rows[i].value / maxV, color: lc.prim, height: 6)),
                const SizedBox(width: 8),
                SizedBox(width: 64, child: Text(Money.fmt(rows[i].value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().topItemsRep!;
    return _RankCard(
      context.tr('Top items'),
      [for (final it in r.items.take(6)) (name: it.name, sub: '${it.qty.toStringAsFixed(0)} ${context.tr('pcs')}', value: it.value)],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().categoryRep!;
    return _RankCard(
      context.tr('Sales by category'),
      [for (final c in r.categories.take(6)) (name: c.name, sub: '', value: c.sales)],
    );
  }
}

class _SalesmanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().salesmanRep!;
    return _RankCard(
      context.tr('By salesman'),
      [for (final s in r.salesmen.take(6)) (name: s.name, sub: '${s.invoices} ${context.tr('invoices')}', value: s.sales)],
    );
  }
}

class _VatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.vatRep!;
    return _Card(
      title: context.tr('VAT summary'),
      child: Column(
        children: [
          _kv(context, context.tr('Output VAT'), Money.fmt(r.outputVat)),
          _kv(context, context.tr('Input VAT'), Money.fmt(r.inputVat)),
          _kv(context, context.tr('Net payable'), '${Money.fmt(r.netPayable)} BHD', big: true, color: r.netPayable >= 0 ? lc.bad : lc.ok),
        ],
      ),
    );
  }
}

class _ValuationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final r = app.valuationRep!;
    return _Card(
      title: context.tr('Inventory valuation'),
      trailing: Text('${Money.fmt(r.totalValue)} BHD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lc.tprim)),
      child: Column(
        children: [
          for (final w in r.byWarehouse)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                Text(Money.fmt(w.value), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
        ],
      ),
    );
  }
}
