import 'dart:io' show File;

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
                  // Photo gallery — real server photos, plus capture / pick.
                  _PhotoStrip(thumb: thumb),
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
                                size: 26, unit: context.tr('BHD · incl. VAT')),
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
                                child: Text(context.tr('Edit barcode / price'),
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
                    options: [context.tr('Details'), context.tr('Product Ledger')],
                    selected: app.prodTab == 'info' ? 0 : 1,
                    onSelect: (i) => app.setProdTab(i == 0 ? 'info' : 'ledger'),
                  ),
                  const SizedBox(height: 12),
                  if (app.prodTab == 'info') ...[
                    LcCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          _InfoRow(context.tr('Category'), p.cat),
                          _InfoRow(context.tr('Brand'), p.brand),
                          _InfoRow(context.tr('Unit'), p.unit),
                          _InfoRow(context.tr('VAT class'), context.tr('Standard 10%')),
                          _InfoRow(context.tr('Cost price'), '${Money.fmt(p.cost)} BHD',
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
                          SectionLabel(context.tr('Stock by warehouse')),
                          const SizedBox(height: 12),
                          for (var i = 0; i < p.wh.length; i++) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.wh[i].$1,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600)),
                                Text('${p.wh[i].$2} ${context.tr('pcs')}',
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
                    child: PrimaryButton(context.tr('Add to memo'),
                        icon: Icons.shopping_cart_outlined,
                        onTap: app.addCurrentToCart)),
                const SizedBox(width: 10),
                Expanded(
                    flex: 10,
                    child: OutlineButton2(context.tr('Count'), onTap: app.goCount)),
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
        child: Center(child: Text(context.tr('No ledger movements'), style: TextStyle(fontSize: 13, color: lc.mut))),
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
              cell(context.tr('DATE'), flex: 15, style: head),
              cell(context.tr('DOCUMENT'), flex: 14, style: head),
              cell(context.tr('QTY'), flex: 7, align: TextAlign.right, style: head),
              cell(context.tr('BALANCE'), flex: 8, align: TextAlign.right, style: head),
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

/// Horizontal photo strip for the product: server photos, the pending local
/// capture while it uploads, and an "add photo" tile.
class _PhotoStrip extends StatelessWidget {
  final Color thumb;
  const _PhotoStrip({required this.thumb});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final images = app.product.images;
    final pending = app.pendingPhotoPath;

    Widget tile({required Widget child, VoidCallback? onTap, VoidCallback? onLongPress}) =>
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: 300,
            margin: const EdgeInsets.only(right: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(14)),
            child: child,
          ),
        );

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Photo being uploaded right now.
              if (pending != null)
                tile(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(pending), fit: BoxFit.cover),
                      if (app.photoUploading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.42),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Text(context.tr('Uploading…'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              // Photos already on the server.
              for (final img in images)
                tile(
                  onLongPress: () => _confirmRemove(context, app, img.id),
                  // Loads through the authenticated API pipeline (Bearer token +
                  // refresh) so protected server photos render instead of
                  // showing a broken image.
                  child: AuthedNetworkImage(url: app.imageUrl(img.url), fit: BoxFit.cover),
                ),
              // Add-photo tile.
              GestureDetector(
                onTap: app.photoUploading ? null : () => _pickSource(context, app),
                child: Container(
                  width: images.isEmpty && pending == null ? 300 : 150,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lc.line, width: 1.5),
                    gradient: images.isEmpty && pending == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [thumb, lc.soft])
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 30,
                          color: images.isEmpty && pending == null
                              ? Colors.white.withValues(alpha: 0.95)
                              : lc.icon),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Add photo'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: images.isEmpty && pending == null
                              ? Colors.white.withValues(alpha: 0.95)
                              : lc.mut,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(context.tr('Long-press a photo to remove it'),
              style: TextStyle(fontSize: 10.5, color: lc.mut)),
        ],
      ],
    );
  }

  Future<void> _pickSource(BuildContext context, AppState app) async {
    final lc = context.lc;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: lc.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4.5, decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: lc.icon),
              title: Text(context.tr('Take photo'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                app.addProductPhoto(fromCamera: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: lc.icon),
              title: Text(context.tr('Choose from gallery'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                app.addProductPhoto(fromCamera: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, AppState app, int imageId) async {
    final lc = context.lc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lc.card,
        title: Text(context.tr('Remove photo?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(context.tr('This deletes the photo from the product.'),
            style: TextStyle(fontSize: 13.5, color: lc.mut)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.tr('Cancel'), style: TextStyle(color: lc.mut))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.tr('Remove'), style: TextStyle(color: lc.bad, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) await app.removeProductPhoto(imageId);
  }
}
