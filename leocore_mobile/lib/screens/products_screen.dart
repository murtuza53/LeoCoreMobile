import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().query);
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
    final rows = app.filteredProducts;

    // Keep controller in sync when state clears the query (e.g. Reset).
    if (_search.text != app.query) {
      _search.value = TextEditingValue(text: app.query, selection: TextSelection.collapsed(offset: app.query.length));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('Products'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  IconChip(Icons.refresh, fg: lc.ink, onTap: app.doRefresh),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SearchField(hint: context.tr('Search name, code or barcode'), controller: _search, onChanged: app.setQuery)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: app.openFilter,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: lc.prim, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.tune, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: app.categoryChips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = app.categoryChips[i];
                    final on = app.cat == c;
                    return GestureDetector(
                      onTap: () => app.pickCat(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? lc.prim : lc.card,
                          border: Border.all(color: on ? lc.prim : lc.line),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: (app.refreshing || (app.dataLoading && rows.isEmpty))
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, __) => _Skeleton(),
                )
              : rows.isEmpty
                  ? _EmptyProducts(onClear: app.clearSearch)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => ProductRow(product: rows[i], onTap: () => app.openProduct(rows[i].id)),
                    ),
        ),
      ],
    );
  }
}

class ProductRow extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductRow({super.key, required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final sub = product.brand.isEmpty ? product.code : '${product.code} · ${product.brand}';
    return LcCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumb(product),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full product name — up to two lines so long names aren't cut off.
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25)),
                const SizedBox(height: 3),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: lc.mut)),
                const SizedBox(height: 6),
                _ListStock(product.stock),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(context.tr('List price'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: lc.mut)),
              const SizedBox(height: 2),
              MoneyText(product.price, size: 15, unit: 'BHD'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Product list thumbnail: shows the first server photo when available,
/// otherwise the coloured initials tile.
class _ProductThumb extends StatelessWidget {
  final Product product;
  const _ProductThumb(this.product);
  @override
  Widget build(BuildContext context) {
    if (product.images.isEmpty) return InitialsThumb(product);
    final lc = context.lc;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(11)),
      child: AuthedNetworkImage(
        url: context.read<AppState>().imageUrl(product.images.first.url),
        fit: BoxFit.cover,
        compact: true,
      ),
    );
  }
}

/// Compact stock indicator for the product list: red when 0 or less, green when
/// positive, and a muted dash when the list endpoint doesn't report stock.
class _ListStock extends StatelessWidget {
  final int stock;
  const _ListStock(this.stock);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    // Unknown (list endpoint omits on-hand) → neutral dash, not a false zero.
    // A real negative (oversold) is NOT unknown — it falls through to red.
    if (stock <= kUnknownStock) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 13, color: lc.mut),
        const SizedBox(width: 5),
        Text('${context.tr('Stock')} —', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.mut)),
      ]);
    }
    final out = stock <= 0;
    final fg = out ? lc.bad : lc.ok;
    final bg = out ? lc.badbg : lc.okbg;
    final label = out ? context.tr('Out of stock') : '$stock ${context.tr('in stock')}';
    return Pill(label, bg: bg, fg: fg, size: 11);
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      height: 72,
      decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyProducts({required this.onClear});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 52, color: lc.line),
            const SizedBox(height: 12),
            Text(context.tr('No products found'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('Try a different name or barcode, or clear the category filter.'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: lc.mut)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onClear,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: lc.prim, width: 1.5)),
                child: Text(context.tr('Clear search'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lc.tprim)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
