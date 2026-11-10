import 'package:flutter/material.dart';

import '../state/paged_list.dart';
import '../theme/tokens.dart';

/// Renders a [PagedList]: spinner on first load, a thin bar while a new search
/// runs, pull-to-refresh, and the next page loads as the end comes into view.
class PagedListView<T> extends StatelessWidget {
  final PagedList<T> list;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const PagedListView({
    super.key,
    required this.list,
    required this.itemBuilder,
    required this.emptyText,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 140),
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final items = list.items;

    if (items.isEmpty && (list.loading || !list.loaded) && list.error == null) {
      return Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4));
    }

    final Widget body;
    if (items.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context.tr(list.error ?? emptyText),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: lc.mut),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: items.length + (list.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: spacing),
        itemBuilder: (ctx, i) {
          if (i >= items.length) {
            // The footer is built as it nears the viewport → fetch the next page.
            WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.2),
                ),
              ),
            );
          }
          return itemBuilder(ctx, items[i]);
        },
      );
    }

    return Stack(
      children: [
        RefreshIndicator(color: lc.prim, onRefresh: list.refresh, child: body),
        if (list.loading && items.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2, color: lc.prim, backgroundColor: Colors.transparent),
          ),
      ],
    );
  }
}

/// "Hide zero balances" / "Sort by balance" chips for party lists.
class PartyFilterChips extends StatelessWidget {
  final bool hideZero;
  final bool byBalance;
  final VoidCallback onHideZero;
  final VoidCallback onByBalance;
  const PartyFilterChips({
    super.key,
    required this.hideZero,
    required this.byBalance,
    required this.onHideZero,
    required this.onByBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Chip(label: context.tr('Hide zero balances'), on: hideZero, onTap: onHideZero, icon: Icons.filter_alt_outlined),
      const SizedBox(width: 8),
      _Chip(label: context.tr('Sort by balance'), on: byBalance, onTap: onByBalance, icon: Icons.sort),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData icon;
  const _Chip({required this.label, required this.on, required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? lc.prim : lc.card,
          border: Border.all(color: on ? lc.prim : lc.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? Colors.white : lc.icon),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
        ]),
      ),
    );
  }
}
