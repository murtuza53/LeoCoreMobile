import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/utils/scan_enhance.dart';
import 'package:leocore_mobile/utils/scan_fix.dart';

const w = 800, h = 1100;

Uint8List _page((num, num, num) Function(int x, int y) f) {
  final b = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = f(x, y);
      final o = (y * w + x) * 3;
      b[o] = c.$1.round().clamp(0, 255);
      b[o + 1] = c.$2.round().clamp(0, 255);
      b[o + 2] = c.$3.round().clamp(0, 255);
    }
  }
  return b;
}

List<int> _px(Uint8List b, int x, int y, [int width = w]) => b.sublist((y * width + x) * 3, (y * width + x) * 3 + 3);

/// Text-like dashes on lines tilted by [deg].
Uint8List _text(double deg) {
  final a = deg * math.pi / 180;
  return _page((x, y) {
    final u = (x - w / 2) * math.cos(a) + (y - h / 2) * math.sin(a);
    final v = (y - h / 2) * math.cos(a) - (x - w / 2) * math.sin(a);
    final ink = v.abs() < 460 && u.abs() < 320 && (v % 32) < 8 && (u % 17) < 11;
    return ink ? (30, 30, 30) : (235, 235, 230);
  });
}

void main() {
  group('shadows', () {
    (num, num, num) shade((num, num, num) c, int x) {
      final s = 1 - 0.4 * (x / w); // soft shadow, darkest at the right
      return (c.$1 * s, c.$2 * s, c.$3 * s);
    }

    test('yellow paper: soft shadow evens out, yellow stays', () {
      final b = _page((x, y) => shade(y % 40 < 6 && x % 50 < 30 ? (40, 40, 45) : (230, 215, 120), x));
      expect(evenLight(b, w, h), isTrue);
      final l = _px(b, 45, 530), r = _px(b, 745, 530);
      expect((l[1] - r[1]).abs(), lessThan(16));
      for (final p in [l, r]) {
        expect(p[2] / p[0], closeTo(120 / 230, 0.04));
      }
    });

    test('a photo and a colour band on white paper are not washed out', () {
      final b = _page((x, y) {
        if (y > 350 && y < 650 && x > 150) return (95, 95, 98); // dark photo
        if (y > 750 && y < 850) return (225, 120, 35); // orange band
        return (215, 215, 212);
      });
      evenLight(b, w, h);
      final paper = _px(b, 400, 100), photo = _px(b, 500, 500), band = _px(b, 400, 800);
      expect(photo[0] / paper[0], closeTo(95 / 215, 0.07));
      expect(band[2] / band[0], closeTo(35 / 225, 0.03));
    });

    test('a photo covering the bottom half keeps its darkness', () {
      final b = _page((x, y) => y > h / 2 ? (90, 100, 120) : (220, 220, 216));
      evenLight(b, w, h);
      expect(_px(b, 400, 950)[0] / _px(b, 400, 150)[0], closeTo(90 / 220, 0.08));
    });
  });

  group('edges', () {
    test('black sliver at the border is filled with paper', () {
      final b = _page((x, y) => y > 500 && x < (y - 500) * 0.04 ? (15, 14, 16) : (240, 235, 200));
      fixDarkEdges(b, w, h);
      expect(_px(b, 2, 1000)[0], greaterThan(220));
      expect(_px(b, 2, 1000)[2], closeTo(200, 10));
    });

    test('dark cover, blue band and pen strokes at the border are kept', () {
      final cover = _page((x, y) => (20, 20, 22));
      final copy = Uint8List.fromList(cover);
      fixDarkEdges(cover, w, h);
      expect(cover, copy);
      final band = _page((x, y) => y < 30 ? (35, 45, 110) : (x < 60 && y > 600 && y < 604 ? (20, 20, 20) : (240, 240, 240)));
      final copy2 = Uint8List.fromList(band);
      fixDarkEdges(band, w, h);
      expect(band, copy2);
    });
  });

  group('straighten', () {
    for (final deg in [-3.0, -1.2, 2.0, 4.0]) {
      test('finds and removes a tilt of $deg°', () {
        final b = _text(deg);
        expect(detectTilt(b, w, h), closeTo(deg, 0.15));
        final r = rotatePage(b, w, h, deg);
        expect(r.w, greaterThanOrEqualTo(w));
        expect(detectTilt(r.rgb, r.w, r.h), 0);
        expect(_px(r.rgb, 0, 0, r.w)[0], greaterThan(220)); // corner = paper
      });
    }

    test('level text, blank pages and noise are left alone', () {
      expect(detectTilt(_text(0), w, h), 0);
      expect(detectTilt(_page((x, y) => (235, 235, 235)), w, h), 0);
      final rnd = math.Random(1);
      expect(detectTilt(_page((x, y) => (rnd.nextInt(256), rnd.nextInt(256), 90)), w, h), 0);
    });
  });

  test('plain Original ignores every fix; Original+ with fixes off too', () {
    for (final a in const [
      ScanAdjust(tone: ScanTone.original),
      ScanAdjust(tone: ScanTone.originalPlus, shadows: false, edges: false, straighten: false),
    ]) {
      final b = _text(3);
      final r = processPage(Uint8List.fromList(b), w, h, a);
      expect((r.w, r.h), (w, h));
      expect(r.rgb, b);
      expect(ScanAdjust.fromList(a.toList()), a);
    }
  });
}
