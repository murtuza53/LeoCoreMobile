import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'scan_fix.dart';

/// How a scanned page is cleaned up.
enum ScanTone {
  /// Shadows and uneven light removed, text darkened, paper colour kept
  /// (a yellow deposit slip stays yellow).
  colour,

  /// Same clean-up, but the paper is turned white (classic "scanner" look).
  white,

  /// Exactly as captured (only straightened and cropped).
  original,

  /// Cleaned like [colour], then shades of grey.
  gray,

  /// Cleaned like [white], then crisp black text on white: best for
  /// text-only pages and small PDFs.
  bw,

  /// The original colours and photos, with soft shadows evened out and no
  /// text darkening.
  originalPlus,
}

/// Everything the user can change for one scanned page.
class ScanAdjust {
  final ScanTone tone;

  /// -50 to 50 (0 = unchanged).
  final int brightness;

  /// -50 to 50 (0 = unchanged).
  final int contrast;

  /// -100 to 100 (0 = unchanged, -100 = no colour).
  final int saturation;

  /// Repairs. [ScanTone.original] ignores all of them; [shadows] only matters
  /// for [ScanTone.originalPlus] (the cleaning filters always remove shadows).
  final bool shadows, edges, straighten;

  const ScanAdjust({
    this.tone = ScanTone.colour,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.shadows = true,
    this.edges = true,
    this.straighten = true,
  });

  ScanAdjust copyWith({
    ScanTone? tone,
    int? brightness,
    int? contrast,
    int? saturation,
    bool? shadows,
    bool? edges,
    bool? straighten,
  }) =>
      ScanAdjust(
        tone: tone ?? this.tone,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        shadows: shadows ?? this.shadows,
        edges: edges ?? this.edges,
        straighten: straighten ?? this.straighten,
      );

  bool get slidersAtZero => brightness == 0 && contrast == 0 && saturation == 0;
  bool get isIdentity => tone == ScanTone.original && slidersAtZero;

  List<int> toList() =>
      [tone.index, brightness, contrast, saturation, shadows ? 1 : 0, edges ? 1 : 0, straighten ? 1 : 0];
  static ScanAdjust fromList(List<int> l) => ScanAdjust(
        tone: ScanTone.values[l[0]],
        brightness: l[1],
        contrast: l[2],
        saturation: l[3],
        shadows: l[4] == 1,
        edges: l[5] == 1,
        straighten: l[6] == 1,
      );

  @override
  bool operator ==(Object other) =>
      other is ScanAdjust &&
      other.tone == tone &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.shadows == shadows &&
      other.edges == edges &&
      other.straighten == straighten;

  @override
  int get hashCode => Object.hash(tone, brightness, contrast, saturation, shadows, edges, straighten);
}

ScanTone scanToneFrom(String? v) =>
    ScanTone.values.firstWhere((t) => t.name == v, orElse: () => ScanTone.colour);

/// Processes one page at full size in a background isolate and returns the
/// new JPEG path (the original path if nothing changes or it fails).
Future<String> processScanPage(String path, ScanAdjust adj, String outDir, int index) async {
  if (adj.isIdentity) return path;
  final target = '$outDir/scan_${DateTime.now().microsecondsSinceEpoch}_$index.jpg';
  try {
    final ok = await compute(_processFile, [path, target, adj.toList()]);
    return ok ? target : path;
  } catch (_) {
    return path;
  }
}

/// A small RGB copy of a page for live previews.
class ScanPreview {
  final Uint8List rgb;
  final int width, height;
  const ScanPreview(this.rgb, this.width, this.height);
}

/// Decodes [path] and shrinks it to [maxSide] for fast previews.
Future<ScanPreview?> loadScanPreview(String path, {int maxSide = 1100}) async {
  try {
    final r = await compute(_loadSmall, [path, maxSide]);
    if (r == null) return null;
    return ScanPreview(r[0] as Uint8List, r[1] as int, r[2] as int);
  } catch (_) {
    return null;
  }
}

/// Applies [adj] to a preview and returns RGBA pixels (for ui.decodeImageFromPixels).
/// The size can differ from the preview's: straightening grows the canvas.
Future<({Uint8List rgba, int w, int h})> renderScanPreview(ScanPreview p, ScanAdjust adj) =>
    compute(_renderPreview, [p.rgb, p.width, p.height, adj.toList()]);

List<Object>? _loadSmall(List<Object> a) {
  final im = _decodeSized(a[0] as String, a[1] as int);
  if (im == null) return null;
  return [Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgb)), im.width, im.height];
}

({Uint8List rgba, int w, int h}) _renderPreview(List<Object> a) {
  final (:rgb, :w, :h) = processPage(
      Uint8List.fromList(a[0] as Uint8List), a[1] as int, a[2] as int, ScanAdjust.fromList((a[3] as List).cast<int>()));
  final out = Uint8List(w * h * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    out[j] = rgb[i];
    out[j + 1] = rgb[i + 1];
    out[j + 2] = rgb[i + 2];
    out[j + 3] = 255;
  }
  return (rgba: out, w: w, h: h);
}

img.Image? _decodeSized(String path, int maxSide) {
  var im = img.decodeImage(File(path).readAsBytesSync());
  if (im == null) return null;
  im = img.bakeOrientation(im);
  if (math.max(im.width, im.height) > maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(im, height: maxSide, interpolation: img.Interpolation.average);
  }
  return im;
}

bool _processFile(List<Object> a) {
  final src = a[0] as String, dst = a[1] as String;
  final adj = ScanAdjust.fromList((a[2] as List).cast<int>());
  final im = _decodeSized(src, 2200);
  if (im == null) return false;
  final (:rgb, :w, :h) =
      processPage(Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgb)), im.width, im.height, adj);
  final res = img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3, order: img.ChannelOrder.rgb);
  File(dst).writeAsBytesSync(img.encodeJpg(res, quality: 88), flush: true);
  return true;
}

/// Repairs, then filter and sliders. May change [rgb] in place; the returned
/// page can be larger when it was straightened.
({Uint8List rgb, int w, int h}) processPage(Uint8List rgb, int w, int h, ScanAdjust a) {
  var page = (rgb: rgb, w: w, h: h);
  if (a.tone != ScanTone.original) {
    if (a.edges) fixDarkEdges(rgb, w, h);
    if (a.straighten) page = rotatePage(rgb, w, h, detectTilt(rgb, w, h));
  }
  applyAdjust(page.rgb, page.w, page.h, a);
  return page;
}

/// Filter, then brightness / contrast / colour, in place.
void applyAdjust(Uint8List rgb, int w, int h, ScanAdjust a) {
  switch (a.tone) {
    case ScanTone.colour:
    case ScanTone.gray:
      enhanceRgb(rgb, w, h, ScanTone.colour);
    case ScanTone.white:
    case ScanTone.bw:
      enhanceRgb(rgb, w, h, ScanTone.white);
    case ScanTone.originalPlus:
      if (a.shadows) evenLight(rgb, w, h);
    case ScanTone.original:
      break;
  }
  final gray = a.tone == ScanTone.gray, bw = a.tone == ScanTone.bw;
  if (!gray && !bw && a.slidersAtZero) return;

  // Brightness + contrast as one lookup table.
  final k = a.contrast >= 0 ? 1 + a.contrast / 50 * 1.2 : 1 + a.contrast / 100;
  final off = a.brightness / 50 * 70;
  final lut = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    lut[i] = ((i - 128) * k + 128 + off).round().clamp(0, 255);
  }
  final sat = (gray || bw) ? 0.0 : 1 + a.saturation / 100;

  for (var o = 0; o < rgb.length; o += 3) {
    var r = lut[rgb[o]].toDouble(), g = lut[rgb[o + 1]].toDouble(), b = lut[rgb[o + 2]].toDouble();
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    if (bw) {
      // Steep curve: nearly binary, but keeps letter edges smooth.
      final v = ((l - 150) * 6 + 128).round().clamp(0, 255);
      rgb[o] = v;
      rgb[o + 1] = v;
      rgb[o + 2] = v;
      continue;
    }
    if (sat != 1) {
      r = l + (r - l) * sat;
      g = l + (g - l) * sat;
      b = l + (b - l) * sat;
    }
    rgb[o] = r.round().clamp(0, 255);
    rgb[o + 1] = g.round().clamp(0, 255);
    rgb[o + 2] = b.round().clamp(0, 255);
  }
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
  if (tone != ScanTone.colour && tone != ScanTone.white) return;
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
