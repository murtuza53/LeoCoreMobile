import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

const _gold = Color(0xFFC9A24B);

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code != null && code.isNotEmpty) {
      context.read<AppState>().onBarcode(code);
    }
  }

  Future<void> _manualEntry() async {
    final app = context.read<AppState>();
    final controller = TextEditingController();
    final lc = context.lc;
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lc.card,
        title: Text(context.tr('Enter barcode'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          style: TextStyle(color: lc.ink),
          decoration: InputDecoration(
            hintText: context.tr('Barcode / code'),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: lc.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: lc.prim2)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.tr('Cancel'), style: TextStyle(color: lc.mut))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(context.tr('Look up'), style: TextStyle(color: lc.tprim, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) app.onBarcode(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Container(
      color: const Color(0xFF0E0B0A),
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconChip(Icons.close, bg: Colors.white.withValues(alpha: 0.12), fg: Colors.white, border: const Border(), onTap: app.closeScan),
                    Text(context.tr('Scan barcode'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    GestureDetector(
                      onTap: () => _scanner.toggleTorch(),
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.flash_on, size: 18, color: _gold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: const Color(0xFF171210)),
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: _onDetect,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error) => _CameraError(onManual: _manualEntry),
                      ),
                      // Dim outside the frame
                      Container(color: Colors.black.withValues(alpha: 0.25)),
                      // Scan frame + line
                      LayoutBuilder(builder: (context, box) {
                        final w = box.maxWidth * 0.78;
                        final h = box.maxHeight * 0.36;
                        return SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            children: [
                              _corner(top: true, left: true),
                              _corner(top: true, left: false),
                              _corner(top: false, left: true),
                              _corner(top: false, left: false),
                              AnimatedBuilder(
                                animation: _ctrl,
                                builder: (_, __) => Positioned(
                                  left: w * 0.06,
                                  right: w * 0.06,
                                  top: h * (0.1 + 0.76 * _ctrl.value),
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.transparent, _gold, Colors.transparent]),
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: const [BoxShadow(color: _gold, blurRadius: 14)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (app.scanLoading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(color: _gold, strokeWidth: 2.6),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.barcode_reader, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(context.tr('EAN-13 · Code-128 · QR — align the code inside the frame'),
                              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.5))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _manualEntry,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(context.tr('Enter barcode manually'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (app.scanFound && app.scanned != null) _MatchSheet(),
        ],
      ),
    );
  }

  Widget _corner({required bool top, required bool left}) {
    const w = 3.5;
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: _gold, width: w) : BorderSide.none,
            bottom: !top ? const BorderSide(color: _gold, width: w) : BorderSide.none,
            left: left ? const BorderSide(color: _gold, width: w) : BorderSide.none,
            right: !left ? const BorderSide(color: _gold, width: w) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(12) : Radius.zero,
            topRight: top && !left ? const Radius.circular(12) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(12) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final VoidCallback onManual;
  const _CameraError({required this.onManual});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171210),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 44, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(context.tr('Camera unavailable'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text(context.tr('Grant camera permission, or enter the barcode manually.'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onManual,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: _gold, width: 1.5), borderRadius: BorderRadius.circular(12)),
              child: Text(context.tr('Enter barcode'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;
    final p = app.scanned!;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(child: GestureDetector(onTap: app.closeScan, child: Container(color: Colors.black.withValues(alpha: 0.5)))),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 44),
              decoration: BoxDecoration(
                color: lc.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, -8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4.5, decoration: BoxDecoration(color: lc.line, borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 14),
                  Row(children: [
                    Pill('✓ ${context.tr('Match found')}', bg: lc.okbg, fg: lc.ok, size: 11),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.barcode.isEmpty ? p.code : p.barcode, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: lc.mut))),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    InitialsThumb(p, size: 54, fontSize: 15),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                          Text('${p.code}${p.brand.isNotEmpty ? ' · ${p.brand}' : ''}', style: TextStyle(fontSize: 12.5, color: lc.mut)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [MoneyText(p.price, size: 16), if (p.stock >= 0) ...[const SizedBox(height: 4), StockBadge(p)]],
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(flex: 10, child: OutlineButton2(context.tr('Open'), height: 48, borderColor: lc.line, onTap: app.openScanned)),
                    const SizedBox(width: 9),
                    Expanded(flex: 14, child: PrimaryButton(context.tr('Add to memo'), height: 48, onTap: app.addScanned)),
                    const SizedBox(width: 9),
                    Expanded(flex: 10, child: OutlineButton2(context.tr('Count'), height: 48, borderColor: lc.gold, onTap: app.countScanned)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
