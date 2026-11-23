import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/tokens.dart';
import '../utils/scan_enhance.dart';
import '../widgets/common.dart';

/// Shown after the scanner returns: pick a filter (auto colour, clean white,
/// grayscale, black & white or original) and fine-tune brightness, contrast
/// and colour per page, with a live preview. Pops with the processed JPEG
/// paths, or null if the scan is discarded.
class ScanEditScreen extends StatefulWidget {
  final List<String> pages;
  final ScanTone initialTone;

  /// Called when the user picks a filter, so it becomes the next default.
  final ValueChanged<ScanTone> onToneChosen;

  const ScanEditScreen({super.key, required this.pages, required this.initialTone, required this.onToneChosen});

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  late final List<String> _pages = [...widget.pages];
  late final List<ScanAdjust> _adj = [for (final _ in widget.pages) ScanAdjust(tone: widget.initialTone)];
  final Map<int, ScanPreview> _previews = {};
  final Map<int, ui.Image> _originals = {};
  int _cur = 0;
  ui.Image? _shown;
  ScanAdjust? _shownAdj;
  int _shownPage = -1;
  bool _rendering = false;
  bool _dirty = false;
  bool _compare = false;
  bool _changed = false;
  int _saving = -1; // page being prepared, -1 = idle

  ScanAdjust get _a => _adj[_cur];

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void dispose() {
    _shown?.dispose();
    for (final i in _originals.values) {
      i.dispose();
    }
    super.dispose();
  }

  Future<ScanPreview?> _preview(int i) async {
    final have = _previews[i];
    if (have != null) return have;
    final p = await loadScanPreview(_pages[i]);
    if (p == null) return null;
    // Keep memory low on long scans: only the current page and its neighbours.
    _previews.removeWhere((k, _) => (k - i).abs() > 1);
    _previews[i] = p;
    return p;
  }

  Future<ui.Image> _toImage(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Renders the current page with its settings. Calls made while a render
  /// is running are merged into one more render when it finishes.
  Future<void> _render() async {
    if (_rendering) {
      _dirty = true;
      return;
    }
    _rendering = true;
    if (mounted) setState(() {});
    try {
      do {
        _dirty = false;
        final page = _cur, adj = _a;
        if (page == _shownPage && adj == _shownAdj) continue;
        final p = await _preview(page);
        if (p == null || !mounted) continue;
        final img = await _toImage(await renderScanPreview(p, adj), p.width, p.height);
        if (!mounted) {
          img.dispose();
          return;
        }
        if (!_originals.containsKey(page)) {
          final o = await _toImage(await renderScanPreview(p, const ScanAdjust(tone: ScanTone.original)), p.width, p.height);
          _originals[page] = o;
        }
        final old = _shown;
        setState(() {
          _shown = img;
          _shownAdj = adj;
          _shownPage = page;
        });
        old?.dispose();
      } while (_dirty && mounted);
    } finally {
      _rendering = false;
      if (mounted) setState(() {});
    }
  }

  void _set(ScanAdjust v) {
    setState(() {
      _adj[_cur] = v;
      _changed = true;
    });
    _render();
  }

  void _pickTone(ScanTone t) {
    widget.onToneChosen(t);
    _set(_a.copyWith(tone: t, saturation: (t == ScanTone.gray || t == ScanTone.bw) ? 0 : null));
  }

  void _goPage(int i) {
    if (i == _cur) return;
    setState(() => _cur = i);
    _render();
  }

  void _applyAll() {
    final v = _a;
    setState(() {
      for (var i = 0; i < _adj.length; i++) {
        _adj[i] = v;
      }
      _changed = true;
    });
    showSnack(context.tr('Applied to all pages'));
  }

  void showSnack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  Future<void> _done() async {
    if (_saving >= 0) return;
    final dir = (await getTemporaryDirectory()).path;
    final out = <String>[];
    for (var i = 0; i < _pages.length; i++) {
      if (!mounted) return;
      setState(() => _saving = i);
      out.add(await processScanPage(_pages[i], _adj[i], dir, i));
    }
    if (!mounted) return;
    Navigator.of(context).pop(out);
  }

  Future<bool> _confirmDiscard() async {
    if (_saving >= 0) return false;
    final lc = context.lc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: lc.card,
        title: Text(context.tr('Discard scan?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(context.tr('The scanned pages will not be attached.'), style: TextStyle(fontSize: 13.5, color: lc.mut)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('Keep editing'))),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(context.tr('Discard'), style: TextStyle(color: lc.bad, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final many = _pages.length > 1;
    final colourless = _a.tone == ScanTone.gray || _a.tone == ScanTone.bw;
    final img = _compare ? (_originals[_cur] ?? _shown) : _shown;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: lc.bg,
        appBar: AppBar(
          backgroundColor: lc.card,
          surfaceTintColor: Colors.transparent,
          title: Text(
            many ? '${context.tr('Adjust pages')} (${_cur + 1}/${_pages.length})' : context.tr('Adjust page'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (!_changed && _saving < 0) {
                Navigator.of(context).pop();
              } else if (await _confirmDiscard() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: _a == ScanAdjust(tone: widget.initialTone) ? null : () => _set(ScanAdjust(tone: widget.initialTone)),
              child: Text(context.tr('Reset'), style: TextStyle(color: lc.tprim, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── preview ──
              Expanded(
                child: GestureDetector(
                  onLongPressStart: (_) => setState(() => _compare = true),
                  onLongPressEnd: (_) => setState(() => _compare = false),
                  onHorizontalDragEnd: !many
                      ? null
                      : (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -250 && _cur < _pages.length - 1) _goPage(_cur + 1);
                          if (v > 250 && _cur > 0) _goPage(_cur - 1);
                        },
                  child: Container(
                    color: lc.soft,
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: img == null || _shownPage != _cur
                              ? Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4))
                              : RawImage(image: img, fit: BoxFit.contain),
                        ),
                        if (_rendering && img != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2)),
                          ),
                        if (_compare)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Pill(context.tr('Original'), bg: lc.ink, fg: lc.card, size: 11),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (many)
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    itemCount: _pages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _goPage(i),
                      child: Container(
                        width: 46,
                        decoration: BoxDecoration(
                          border: Border.all(color: i == _cur ? lc.prim : lc.line, width: i == _cur ? 2 : 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(fit: StackFit.expand, children: [
                          Image.file(File(_pages[i]), fit: BoxFit.cover, cacheWidth: 120),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black54,
                              child: Text('${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              // ── filters ──
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  children: [
                    for (final t in const [ScanTone.colour, ScanTone.white, ScanTone.gray, ScanTone.bw, ScanTone.original]) ...[
                      _FilterChip(
                        label: context.tr(_toneLabel(t)),
                        icon: _toneIcon(t),
                        on: _a.tone == t,
                        onTap: () => _pickTone(t),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              // ── sliders ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Column(children: [
                  _SliderRow(
                    icon: Icons.light_mode_outlined,
                    label: context.tr('Brightness'),
                    value: _a.brightness,
                    min: -50,
                    max: 50,
                    onChanged: (v) => _set(_a.copyWith(brightness: v)),
                  ),
                  _SliderRow(
                    icon: Icons.contrast,
                    label: context.tr('Contrast'),
                    value: _a.contrast,
                    min: -50,
                    max: 50,
                    onChanged: (v) => _set(_a.copyWith(contrast: v)),
                  ),
                  _SliderRow(
                    icon: Icons.palette_outlined,
                    label: context.tr('Colour'),
                    value: _a.saturation,
                    min: -100,
                    max: 100,
                    onChanged: colourless ? null : (v) => _set(_a.copyWith(saturation: v)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(context.tr('Hold the page to see the original'), style: TextStyle(fontSize: 11, color: lc.mut)),
                  ),
                  if (many)
                    TextButton.icon(
                      onPressed: _applyAll,
                      icon: Icon(Icons.done_all, size: 16, color: lc.tprim),
                      label: Text(context.tr('Apply to all pages'),
                          style: TextStyle(fontSize: 12.5, color: lc.tprim, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: PrimaryButton(
                  _saving >= 0
                      ? '${context.tr('Preparing page')} ${_saving + 1}/${_pages.length}…'
                      : context.tr('Create PDF'),
                  icon: Icons.picture_as_pdf_outlined,
                  busy: _saving >= 0,
                  onTap: _done,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _toneLabel(ScanTone t) => switch (t) {
        ScanTone.colour => 'Auto colour',
        ScanTone.white => 'Clean white',
        ScanTone.gray => 'Grayscale',
        ScanTone.bw => 'Black & white',
        ScanTone.original => 'Original',
      };

  static IconData _toneIcon(ScanTone t) => switch (t) {
        ScanTone.colour => Icons.auto_fix_high,
        ScanTone.white => Icons.cleaning_services_outlined,
        ScanTone.gray => Icons.filter_b_and_w,
        ScanTone.bw => Icons.text_snippet_outlined,
        ScanTone.original => Icons.image_outlined,
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
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

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value, min, max;
  final ValueChanged<int>? onChanged;
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final off = onChanged == null;
    return SizedBox(
      height: 38,
      child: Row(children: [
        Icon(icon, size: 18, color: off ? lc.line : lc.icon),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: off ? lc.mut : lc.ink)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              activeColor: lc.prim,
              inactiveColor: lc.line,
              onChanged: off ? null : (v) => onChanged!(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value > 0 ? '+$value' : '$value',
              textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: lc.mut, fontFeatures: const [ui.FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}
