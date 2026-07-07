import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final p = app.product;
    final thumb = LcColors.catColors[p.cat] ?? lc.prim;
    final whMax = p.wh.map((w) => w.$2).fold(1, (a, b) => a > b ? a : b);

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: p.name,
              subtitle: p.code,
              onBack: () => app.nav(Screen.products),
              topPad: 60,
              actions: [IconChip(Icons.open_in_new, fg: lc.ink)],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // Photo carousel
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Container(
                          width: 300,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [thumb, lc.soft]),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined,
                                  size: 34,
                                  color: Colors.white.withValues(alpha: 0.9)),
                              const SizedBox(height: 8),
                              Text('Product photo 1 · placeholder',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white
                                          .withValues(alpha: 0.95))),
                            ],
                          ),
                        ),
                        for (final n in [2, 3])
                          Container(
                            width: 300,
                            margin: const EdgeInsets.only(right: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: lc.soft,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text('Photo $n · placeholder',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: lc.mut)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 16,
                          height: 5,
                          decoration: BoxDecoration(
                              color: lc.prim,
                              borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 5),
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: lc.line,
                              borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 5),
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: lc.line,
                              borderRadius: BorderRadius.circular(99))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price card
                  LcCard(
                    shadow: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            MoneyText(p.price,
                                size: 26, unit: 'BHD · incl. VAT'),
                            StockBadge(p, size: 11),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                              color: lc.soft,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Icon(Icons.barcode_reader,
                                  size: 18, color: lc.ink),
                              const SizedBox(width: 9),
                              Expanded(
                                  child: Text(p.barcode,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.4))),
                              GestureDetector(
                                onTap: app.openEdit,
                                child: Text('Edit barcode / price',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: lc.tprim)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Segmented(
                    options: const ['Details', 'Product Ledger'],
                    selected: app.prodTab == 'info' ? 0 : 1,
                    onSelect: (i) => app.setProdTab(i == 0 ? 'info' : 'ledger'),
                  ),
                  const SizedBox(height: 12),
                  if (app.prodTab == 'info') ...[
                    LcCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          _InfoRow('Category', p.cat),
                          _InfoRow('Brand', p.brand),
                          _InfoRow('Unit', p.unit),
                          const _InfoRow('VAT class', 'Standard 10%'),
                          _InfoRow('Cost price', '${Money.fmt(p.cost)} BHD',
                              last: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    LcCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionLabel('Stock by warehouse'),
                          const SizedBox(height: 12),
                          for (var i = 0; i < p.wh.length; i++) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.wh[i].$1,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600)),
                                Text('${p.wh[i].$2} pcs',
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            BarTrack(
                                fraction: p.wh[i].$2 / whMax, color: lc.prim),
                            if (i != p.wh.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ] else
                    _LedgerCard(),
                ],
              ),
            ),
          ],
        ),
        // Bottom action bar
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
                    flex: 15,
                    child: PrimaryButton('Add to cart',
                        icon: Icons.shopping_cart_outlined,
                        onTap: app.addCurrentToCart)),
                const SizedBox(width: 10),
                Expanded(
                    flex: 10,
                    child: OutlineButton2('Count', onTap: app.goCount)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  const _InfoRow(this.label, this.value, {this.last = false});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: lc.line))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: lc.mut)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final app = context.watch<AppState>();
    final rows = app.ledgerRows;
    Widget cell(String s,
            {int flex = 1,
            TextAlign align = TextAlign.left,
            TextStyle? style}) =>
        Expanded(flex: flex, child: Text(s, textAlign: align, style: style));
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: lc.mut);

    if (app.ledgerLoading && rows.isEmpty) {
      return LcCard(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4)),
      );
    }
    if (rows.isEmpty) {
      return LcCard(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No ledger movements', style: TextStyle(fontSize: 13, color: lc.mut))),
      );
    }

    return LcCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: lc.line))),
            child: Row(children: [
              cell('DATE', flex: 15, style: head),
              cell('DOCUMENT', flex: 14, style: head),
              cell('QTY', flex: 7, align: TextAlign.right, style: head),
              cell('BALANCE', flex: 8, align: TextAlign.right, style: head),
            ]),
          ),
          for (var i = 0; i < rows.length; i++)
            Builder(builder: (_) {
              final l = rows[i];
              final pos = l.qty > 0;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: i == rows.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(bottom: BorderSide(color: lc.line))),
                child: Row(children: [
                  cell(l.d,
                      flex: 15,
                      style: TextStyle(fontSize: 12.5, color: lc.mut)),
                  cell(l.doc,
                      flex: 14,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  cell('${pos ? '+' : ''}${l.qty}',
                      flex: 7,
                      align: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: pos ? lc.ok : lc.bad)),
                  cell('${l.bal}',
                      flex: 8,
                      align: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
