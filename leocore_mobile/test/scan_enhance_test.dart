import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/utils/scan_enhance.dart';

/// A yellow slip photographed with a shadow falling across the right half,
/// with a few dark "text" bars on it.
Uint8List _yellowSlip(int w, int h) {
  final b = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final shade = x < w / 2 ? 1.0 : 0.6; // shadow on the right half
      final text = (y % 40) < 6 && (x % 100) < 70;
      final o = (y * w + x) * 3;
      final (r, g, bl) = text ? (40, 40, 45) : (235, 220, 120); // yellow paper
      b[o] = (r * shade).round();
      b[o + 1] = (g * shade).round();
      b[o + 2] = (bl * shade).round();
    }
  }
  return b;
}

(int, int, int) _px(Uint8List b, int w, int x, int y) {
  final o = (y * w + x) * 3;
  return (b[o], b[o + 1], b[o + 2]);
}

void main() {
  const w = 800, h = 1000;
  // A paper pixel (not on a text bar) in the lit and the shaded half.
  const lit = (200, 530), shaded = (600, 530);

  test('colour mode keeps the yellow paper and removes the shadow', () {
    final b = _yellowSlip(w, h);
    enhanceRgb(b, w, h, ScanTone.colour);
    final a = _px(b, w, lit.$1, lit.$2), s = _px(b, w, shaded.$1, shaded.$2);
    // Still clearly yellow: blue well below red/green.
    expect(a.$3, lessThan(a.$1 - 60));
    expect(s.$3, lessThan(s.$1 - 60));
    // Shadow gone: both halves end up about equally bright.
    expect((a.$2 - s.$2).abs(), lessThan(14));
    // Text dark.
    final t = _px(b, w, 610, 2);
    expect(t.$1, lessThan(60));
  });

  test('white mode turns the paper white', () {
    final b = _yellowSlip(w, h);
    enhanceRgb(b, w, h, ScanTone.white);
    final s = _px(b, w, shaded.$1, shaded.$2);
    expect(s.$1, greaterThan(235));
    expect(s.$3, greaterThan(235));
  });

  test('original mode leaves pixels untouched', () {
    final b = _yellowSlip(w, h);
    final copy = Uint8List.fromList(b);
    enhanceRgb(b, w, h, ScanTone.original);
    expect(b, copy);
  });
}
