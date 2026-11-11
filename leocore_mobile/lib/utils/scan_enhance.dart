import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// How a scanned page is cleaned up.
enum ScanTone {
  /// Shadows and uneven light removed, text darkened, paper colour kept
  /// (a yellow deposit slip stays yellow).
  colour,

  /// Same clean-up, but the paper is turned white (classic "scanner" look).
  white,

  /// Exactly as captured (only straightened and cropped).
  original,
}

ScanTone scanToneFrom(String? v) =>
    ScanTone.values.firstWhere((t) => t.name == v, orElse: () => ScanTone.colour);

/// Cleans every page in a background isolate and returns the new JPEG paths.
/// A page that can't be processed is passed through unchanged.
Future<List<String>> enhanceScans(List<String> paths, ScanTone tone, String outDir) async {
  if (tone == ScanTone.original) return paths;
  final out = <String>[];
  for (var i = 0; i < paths.length; i++) {
    final target = '$outDir/scan_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
    try {
      final ok = await compute(_enhanceFile, [paths[i], target, tone.index]);
      out.add(ok ? target : paths[i]);
    } catch (_) {
      out.add(paths[i]);
    }
  }
  return out;
}

bool _enhanceFile(List<Object> a) {
  final src = a[0] as String, dst = a[1] as String;
  final tone = ScanTone.values[a[2] as int];
  var im = img.decodeImage(File(src).readAsBytesSync());
  if (im == null) return false;
  im = img.bakeOrientation(im);
  const maxSide = 2200;
  if (math.max(im.width, im.height) > maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(im, height: maxSide, interpolation: img.Interpolation.average);
  }
  final w = im.width, h = im.height;
  final rgb = Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgb));
  enhanceRgb(rgb, w, h, tone);
  final res = img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3, order: img.ChannelOrder.rgb);
  File(dst).writeAsBytesSync(img.encodeJpg(res, quality: 88), flush: true);
  return true;
}

/// In-place clean-up of an RGB buffer.
///
/// 1. Estimate the paper ("background") brightness across the page from the
///    bright end of each small block — text is dark, so it drops out.
/// 2. Divide it out: shadows, vignetting and uneven light flatten away.
///    [ScanTone.colour] applies ONE gain to R, G and B, so hue and saturation
///    are kept; [ScanTone.white] normalises each channel separately, which
///    also neutralises the paper colour to white.
/// 3. A tone curve pushes ink towards black while leaving paper untouched.
void enhanceRgb(Uint8List rgb, int w, int h, ScanTone tone) {
  if (tone == ScanTone.original) return;
  final white = tone == ScanTone.white;
  final bs = math.max(16, (math.max(w, h) / 48).round());
  final gw = (w + bs - 1) ~/ bs, gh = (h + bs - 1) ~/ bs;
  final nCh = white ? 3 : 1;
  // Background per block and channel (luminance only in colour mode).
  final grid = List.generate(nCh, (_) => Float64List(gw * gh));
  final hist = List.generate(nCh, (_) => Int32List(256));
  const step = 2; // sample every other pixel — plenty for a percentile

  for (var by = 0; by < gh; by++) {
    for (var bx = 0; bx < gw; bx++) {
      for (final hh in hist) {
        hh.fillRange(0, 256, 0);
      }
      var n = 0;
      final y1 = math.min(h, (by + 1) * bs), x1 = math.min(w, (bx + 1) * bs);
      for (var y = by * bs; y < y1; y += step) {
        var o = (y * w + bx * bs) * 3;
        for (var x = bx * bs; x < x1; x += step, o += 3 * step) {
          final r = rgb[o], g = rgb[o + 1], b = rgb[o + 2];
          if (white) {
            hist[0][r]++;
            hist[1][g]++;
            hist[2][b]++;
          } else {
            hist[0][(r * 77 + g * 150 + b * 29) >> 8]++;
          }
          n++;
        }
      }
      // 90th percentile = paper, as long as ink covers < 10% of the block.
      final want = (n * 0.9).floor();
      for (var c = 0; c < nCh; c++) {
        var acc = 0, v = 255;
        for (var i = 0; i < 256; i++) {
          acc += hist[c][i];
          if (acc > want) {
            v = i;
            break;
          }
        }
        grid[c][by * gw + bx] = v.toDouble();
      }
    }
  }

  // Ink-heavy blocks read too dark: lift each block to its brightest
  // neighbour, then soften so the correction has no visible tiles.
  for (var c = 0; c < nCh; c++) {
    grid[c] = _box(_maxFilter(grid[c], gw, gh), gw, gh);
  }

  // Paper ends up at ~245/255 (colour keeps tint) or ~250 (white).
  final paper = white ? 250.0 : 242.0;
  const black = 0.13, gamma = 1.35;
  final outPaper = paper / 255.0;

  for (var y = 0; y < h; y++) {
    final fy = ((y + 0.5) / bs - 0.5).clamp(0.0, gh - 1.0);
    final y0 = fy.floor(), yy1 = math.min(y0 + 1, gh - 1);
    final ty = fy - y0;
    var o = y * w * 3;
    for (var x = 0; x < w; x++, o += 3) {
      final fx = ((x + 0.5) / bs - 0.5).clamp(0.0, gw - 1.0);
      final x0 = fx.floor(), xx1 = math.min(x0 + 1, gw - 1);
      final tx = fx - x0;
      double bg(Float64List gr) {
        final a = gr[y0 * gw + x0] + (gr[y0 * gw + xx1] - gr[y0 * gw + x0]) * tx;
        final b = gr[yy1 * gw + x0] + (gr[yy1 * gw + xx1] - gr[yy1 * gw + x0]) * tx;
        return a + (b - a) * ty;
      }

      var r = rgb[o].toDouble(), g = rgb[o + 1].toDouble(), b = rgb[o + 2].toDouble();
      if (white) {
        r *= (paper / math.max(bg(grid[0]), 40)).clamp(0.9, 4.0);
        g *= (paper / math.max(bg(grid[1]), 40)).clamp(0.9, 4.0);
        b *= (paper / math.max(bg(grid[2]), 40)).clamp(0.9, 4.0);
      } else {
        final k = (paper / math.max(bg(grid[0]), 40)).clamp(0.9, 2.6);
        r *= k;
        g *= k;
        b *= k;
      }
      // Tone curve on brightness; scale RGB together so colour is kept.
      final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      if (lum > 0.001) {
        final t = ((lum - black) / (outPaper - black)).clamp(0.0, 1.0);
        final target = outPaper * math.pow(t, gamma);
        final s = target / lum;
        r *= s;
        g *= s;
        b *= s;
      }
      rgb[o] = r.round().clamp(0, 255);
      rgb[o + 1] = g.round().clamp(0, 255);
      rgb[o + 2] = b.round().clamp(0, 255);
    }
  }
}

Float64List _maxFilter(Float64List g, int w, int h) {
  final o = Float64List(g.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          m = math.max(m, g[yy * w + xx]);
        }
      }
      o[y * w + x] = m;
    }
  }
  return o;
}

Float64List _box(Float64List g, int w, int h) {
  final o = Float64List(g.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          s += g[yy * w + xx];
          n++;
        }
      }
      o[y * w + x] = s / n;
    }
  }
  return o;
}
