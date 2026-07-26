import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Shared scrim + bottom sheet chrome (grab handle, rounded top, shadow).
class BottomSheetShell extends StatelessWidget {
  final VoidCallback onDismiss;
  final List<Widget> children;
  const BottomSheetShell({super.key, required this.onDismiss, required this.children});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 46),
              decoration: BoxDecoration(
                color: lc.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Company & warehouse switcher.
class WarehouseSheet extends StatelessWidget {
  const WarehouseSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;

    Widget whRow(IconData icon, String name, String meta, {int? id}) {
      final selected = app.wh == name;
      return GestureDetector(
        onTap: () => app.pickWh(name, id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: lc.icon),
              const SizedBox(width: 11),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 11.5, color: lc.mut)),
              if (selected) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: lc.ok)),
            ],
          ),
        ),
      );
    }

    final live = !app.demoMode && app.warehouseOptions.isNotEmpty;

    return BottomSheetShell(
      onDismiss: app.closeWhSheet,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(context.tr('Company & warehouse'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const LcLogo(size: 34),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.companyLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(app.companySub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: lc.mut)),
                  ],
                ),
              ),
              Text('✓', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lc.ok)),
            ],
          ),
        ),
        if (live)
          for (final w in app.warehouseOptions) whRow(Icons.home_outlined, w.name, w.code, id: w.id)
        else ...[
          whRow(Icons.home_outlined, 'Main WH · Tubli', '1,240 SKUs'),
          whRow(Icons.local_shipping_outlined, 'Van 12 · Yousif', '86 SKUs'),
          whRow(Icons.store_mall_directory_outlined, 'Sitra Store', '412 SKUs'),
        ],
      ],
    );
  }
}

/// Products filter sheet (category chips + stock status).
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    Widget chip(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? lc.prim : lc.card,
              border: Border.all(color: on ? lc.prim : lc.line),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
          ),
        );

    return BottomSheetShell(
      onDismiss: app.closeFilter,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('Filters'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: app.clearSearch,
              child: Text(context.tr('Reset'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lc.tprim)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionLabel(context.tr('Category'), size: 11.5),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in app.categoryChips) chip(c, app.cat == c, () => app.pickCat(c))],
        ),
        const SizedBox(height: 14),
        SectionLabel(context.tr('Stock status'), size: 11.5),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(context.tr('All'), true, () {}),
            chip(context.tr('In stock'), false, () {}),
            chip(context.tr('Low'), false, () {}),
            chip(context.tr('Out of stock'), false, () {}),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(context.tr('Apply filters'), height: 50, onTap: app.applyFilter),
      ],
    );
  }
}

/// Edit barcode & price sheet.
class EditSheet extends StatefulWidget {
  const EditSheet({super.key});
  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  late final TextEditingController _barcode;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _barcode = TextEditingController(text: app.editBarcode);
    _price = TextEditingController(text: app.editPrice);
  }

  @override
  void dispose() {
    _barcode.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;

    InputDecoration dec() => InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: lc.bg,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: lc.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: lc.prim2)),
        );

    return BottomSheetShell(
      onDismiss: app.closeEdit,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Edit barcode & price'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(app.product.name, style: TextStyle(fontSize: 12, color: lc.mut)),
          ],
        ),
        const SizedBox(height: 14),
        Text(context.tr('Barcode (EAN-13)'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.mut)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcode,
                onChanged: app.setEditBarcode,
                style: TextStyle(fontSize: 15, color: lc.ink),
                decoration: dec(),
              ),
            ),
            const SizedBox(width: 8),
            IconChip(Icons.qr_code_scanner, size: 48, fg: lc.gold, border: Border.all(color: lc.gold, width: 1.5), onTap: app.openScan),
          ],
        ),
        const SizedBox(height: 14),
        Text(context.tr('Selling price (BHD, incl. VAT)'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.mut)),
        const SizedBox(height: 6),
        TextField(
          controller: _price,
          onChanged: app.setEditPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: lc.ink),
          decoration: dec(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: OutlineButton2(context.tr('Cancel'), height: 50, borderColor: lc.line, onTap: app.closeEdit)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(context.tr('Save changes'), height: 50, onTap: app.saveEdit)),
          ],
        ),
      ],
    );
  }
}
