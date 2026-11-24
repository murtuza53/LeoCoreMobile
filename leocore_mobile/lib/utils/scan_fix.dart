import 'dart:math' as math;
import 'dart:typed_data';

// Page repairs for scans — plain image processing, no AI. Every step is
// conservative: when the evidence is weak the page is left as it was.

int _lum(Uint8List p, int o) => (p[o] * 77 + p[o + 1] * 150 + p[o + 2] * 29) >> 8;

// ── Edges ──────────────────────────────────────────────────────────────────

/// Paints over black slivers (table, gap under the page) that touch the image
/// border. A sliver must be near-black and neutral, narrower than 6% of the
/// page, continue along at least 2% of that side, and have brighter paper
/// behind it — so dark covers, printed bands, lines and pen strokes are kept.
void fixDarkEdges(Uint8List rgb, int w, int h) {
  if (w < 50 || h < 50) return;
  _edge(rgb, h, w, (i, d) => (i * w + d) * 3); // left
  _edge(rgb, h, w, (i, d) => (i * w + w - 1 - d) * 3); // right
  _edge(rgb, w, h, (i, d) => (d * w + i) * 3); // top
  _edge(rgb, w, h, (i, d) => ((h - 1 - d) * w + i) * 3); // bottom
}

void _edge(Uint8List p, int along, int depth, int Function(int i, int d) at) {
  final maxRun = math.max(2, (depth * 0.06).round());
  final blend = math.max(2, (depth * 0.004).round()); // soft rim of the sliver
  final run = Int32List(along);
  for (var i = 0; i < along; i++) {
    var d = 0;
    while (d <= maxRun) {
      final o = at(i, d);
      final hi = math.max(p[o], math.max(p[o + 1], p[o + 2]));
      final lo = math.min(p[o], math.min(p[o + 1], p[o + 2]));
      if (hi >= 80 || hi - lo >= 28) break;
      d++;
    }
    if (d == 0 || d > maxRun) continue;
    if (_lum(p, at(i, math.min(depth - 1, d + blend + 2))) < 110) continue;
    run[i] = d;
  }
  final need = math.max(6, (along * 0.02).round());
  var s = 0;
  while (s < along) {
    if (run[s] == 0) {
      s++;
      continue;
    }
    var e = s;
    while (e < along && run[e] > 0) {
      e++;
    }
    if (e - s >= need) {
      for (var i = s; i < e; i++) {
        final end = run[i] + blend;
        var r = 0, g = 0, b = 0, n = 0;
        for (var d = end + 1; d < math.min(depth, end + 6); d++) {
          final o = at(i, d);
          r += p[o];
          g += p[o + 1];
          b += p[o + 2];
          n++;
        }
        if (n == 0) continue;
        for (var d = 0; d < end; d++) {
          final o = at(i, d);
          p[o] = r ~/ n;
          p[o + 1] = g ~/ n;
          p[o + 2] = b ~/ n;
        }
      }
    }
    s = e;
  }
}

// ── Straighten ─────────────────────────────────────────────────────────────

/// Tilt of the page content in degrees (positive = lines fall to the right),
/// or 0 when there is no clear answer. Text lines and ruled lines stack into
/// sharp peaks when projected along their own direction.
double detectTilt(Uint8List rgb, int w, int h) {
  final step = math.max(1, (math.max(w, h) / 700).ceil());
  final sw = w ~/ step, sh = h ~/ step;
  if (sw < 60 || sh < 60) return 0;
  final g = Uint8List(sw * sh);
  for (var y = 0; y < sh; y++) {
    for (var x = 0; x < sw; x++) {
      var s = 0, n = 0;
      for (var yy = y * step; yy < (y + 1) * step; yy++) {
        for (var xx = x * step; xx < (x + 1) * step; xx++) {
          s += _lum(rgb, (yy * w + xx) * 3);
          n++;
        }
      }
      g[y * sw + x] = s ~/ n;
    }
  }
  final xs = <int>[], ys = <int>[];
  // Skip the rim: the photographed page border is not content.
  final mx = (sw * 0.05).round(), my = (sh * 0.05).round();
  for (var y = my + 1; y < sh - my - 1; y++) {
    for (var x = mx; x < sw - mx; x++) {
      if (g[(y - 1) * sw + x] - g[(y + 1) * sw + x] > 28) {
        xs.add(x - sw ~/ 2);
        ys.add(y - sh ~/ 2);
      }
    }
  }
  if (xs.length < 400) return 0;
  final off = sw + sh;
  final hist = Float64List(off * 2);
  double score(double deg) {
    final a = deg * math.pi / 180, c = math.cos(a), s = math.sin(a);
    hist.fillRange(0, hist.length, 0);
    for (var i = 0; i < xs.length; i++) {
      final v = ys[i] * c - xs[i] * s + off;
      final k = v.floor();
      final f = v - k;
      hist[k] += 1 - f;
      hist[k + 1] += f;
    }
    var t = 0.0;
    for (final v in hist) {
      t += v * v;
    }
    return t;
  }

  const limit = 5.0;
  var best = 0.0, bestS = -1.0;
  final all = <double>[];
  for (var i = -20; i <= 20; i++) {
    final s = score(i * 0.25);
    all.add(s);
    if (s > bestS) {
      bestS = s;
      best = i * 0.25;
    }
  }
  if (best.abs() >= limit) return 0; // still rising: not a small tilt
  final coarse = best;
  for (var i = -5; i <= 5; i++) {
    final a = coarse + i * 0.05, s = score(a);
    if (s > bestS) {
      bestS = s;
      best = a;
    }
  }
  all.sort();
  if (bestS < all[all.length ~/ 2] * 1.25 || bestS < score(0) * 1.04) return 0;
  return best.abs() < 0.3 ? 0 : best;
}

/// Rotates by [deg] so lines tilted by that much become level. The canvas
/// grows so nothing is cut off; new corners get the paper colour.
({Uint8List rgb, int w, int h}) rotatePage(Uint8List src, int w, int h, double deg) {
  if (deg == 0) return (rgb: src, w: w, h: h);
  final a = deg * math.pi / 180, c = math.cos(a), s = math.sin(a);
  final nw = (w * c.abs() + h * s.abs()).ceil(), nh = (w * s.abs() + h * c.abs()).ceil();
  final paper = _paperColour(src, w, h);
  final out = Uint8List(nw * nh * 3);
  final cx = (w - 1) / 2, cy = (h - 1) / 2, ncx = (nw - 1) / 2, ncy = (nh - 1) / 2;
  for (var y = 0; y < nh; y++) {
    final dy = y - ncy;
    for (var x = 0; x < nw; x++) {
      final dx = x - ncx;
      final sx = dx * c - dy * s + cx, sy = dx * s + dy * c + cy;
      final o = (y * nw + x) * 3;
      if (sx < 0 || sy < 0 || sx > w - 1 || sy > h - 1) {
        out[o] = paper.$1;
        out[o + 1] = paper.$2;
        out[o + 2] = paper.$3;
        continue;
      }
      final x0 = sx.floor(), y0 = sy.floor();
      final x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
      final fx = sx - x0, fy = sy - y0;
      final p00 = (y0 * w + x0) * 3, p01 = (y0 * w + x1) * 3, p10 = (y1 * w + x0) * 3, p11 = (y1 * w + x1) * 3;
      for (var k = 0; k < 3; k++) {
        final t = src[p00 + k] + (src[p01 + k] - src[p00 + k]) * fx;
        final b = src[p10 + k] + (src[p11 + k] - src[p10 + k]) * fx;
        out[o + k] = (t + (b - t) * fy).round();
      }
    }
  }
  return (rgb: out, w: nw, h: nh);
}

/// Average colour of the bright 30% of the page.
(int, int, int) _paperColour(Uint8List p, int w, int h) {
  final hist = Int32List(256);
  var n = 0;
  const st = 3 * 7;
  for (var o = 0; o + 2 < p.length; o += st) {
    hist[_lum(p, o)]++;
    n++;
  }
  var acc = 0, cut = 255;
  while (cut > 0 && acc + hist[cut] < n * 0.3) {
    acc += hist[cut--];
  }
  var r = 0, g = 0, b = 0, m = 0;
  for (var o = 0; o + 2 < p.length; o += st) {
    if (_lum(p, o) < cut) continue;
    r += p[o];
    g += p[o + 1];
    b += p[o + 2];
    m++;
  }
  return m == 0 ? (255, 255, 255) : (r ~/ m, g ~/ m, b ~/ m);
}

// ── Shadows (Original+) ────────────────────────────────────────────────────

/// Evens out soft shadows while keeping colours and photos: one smooth light
/// surface is fitted to the paper-coloured parts of the whole page and divided
/// out with the same gain for R, G and B. Returns false (page untouched) when
/// too little paper is visible to judge the light.
bool evenLight(Uint8List rgb, int w, int h) {
  const gw = 28, gh = 36;
  if (w < gw * 4 || h < gh * 4) return false;
  const n = gw * gh;
  final lum = Float64List(n), cr = Float64List(n), cb = Float64List(n);
  final hist = Int32List(256);
  for (var by = 0; by < gh; by++) {
    for (var bx = 0; bx < gw; bx++) {
      final x0 = bx * w ~/ gw, x1 = (bx + 1) * w ~/ gw, y0 = by * h ~/ gh, y1 = (by + 1) * h ~/ gh;
      hist.fillRange(0, 256, 0);
      var cnt = 0;
      for (var y = y0; y < y1; y += 2) {
        for (var x = x0; x < x1; x += 2) {
          hist[_lum(rgb, (y * w + x) * 3)]++;
          cnt++;
        }
      }
      var acc = 0, v = 255;
      while (v > 0 && acc + hist[v] < cnt * 0.15) {
        acc += hist[v--];
      }
      var r = 0.0, g = 0.0, b = 0.0;
      var m = 0;
      for (var y = y0; y < y1; y += 2) {
        for (var x = x0; x < x1; x += 2) {
          final o = (y * w + x) * 3;
          if (_lum(rgb, o) < v) continue;
          r += rgb[o];
          g += rgb[o + 1];
          b += rgb[o + 2];
          m++;
        }
      }
      final i = by * gw + bx;
      final sum = math.max(r + g + b, 1.0);
      lum[i] = math.max(v.toDouble(), 1);
      cr[i] = m == 0 ? 0 : r / sum;
      cb[i] = m == 0 ? 0 : b / sum;
    }
  }

  // The paper: bright blocks sharing the page's main colour.
  final sorted = [...lum]..sort();
  final p95 = sorted[(n * 0.95).floor()];
  if (p95 < 70) return false;
  final brightCut = sorted[(n * 0.6).floor()];
  final br = <double>[], bb = <double>[];
  for (var i = 0; i < n; i++) {
    if (lum[i] >= brightCut) {
      br.add(cr[i]);
      bb.add(cb[i]);
    }
  }
  br.sort();
  bb.sort();
  final mr = br[br.length ~/ 2], mb = bb[bb.length ~/ 2];
  final wt = Float64List(n);
  var used = 0;
  for (var i = 0; i < n; i++) {
    if (lum[i] >= p95 * 0.5 && (cr[i] - mr).abs() < 0.035 && (cb[i] - mb).abs() < 0.035) {
      wt[i] = 1;
      used++;
    }
  }
  if (used < n * 0.3) return false;

  // Smooth surface in log brightness. Blocks well below it (photos, print)
  // lose their say, so the surface rides on the paper.
  List<double>? k;
  final base = Float64List.fromList(wt);
  for (var it = 0; it < 6; it++) {
    k = _fit(lum, wt, gw, gh);
    if (k == null) return false;
    for (var i = 0; i < n; i++) {
      if (base[i] == 0) continue;
      final d = math.log(lum[i]) - _eval(k, (i % gw + 0.5) / gw * 2 - 1, (i ~/ gw + 0.5) / gh * 2 - 1);
      wt[i] = d > -0.04 ? 1 : math.exp(-math.pow((d + 0.04) / 0.06, 2).toDouble()) + 0.002;
    }
  }
  // A surface most paper blocks don't follow is not the light.
  var near = 0;
  for (var i = 0; i < n; i++) {
    if (base[i] > 0 && wt[i] > 0.4) near++;
  }
  if (near < n * 0.2) return false;

  final fit = Float64List(n);
  var lo = double.infinity;
  for (var i = 0; i < n; i++) {
    fit[i] = math.exp(_eval(k!, (i % gw + 0.5) / gw * 2 - 1, (i ~/ gw + 0.5) / gh * 2 - 1));
    if (base[i] > 0 && wt[i] > 0.4) lo = math.min(lo, lum[i]);
  }
  // Where there is no paper the surface is a guess: never darker than paper seen.
  for (var i = 0; i < n; i++) {
    fit[i] = fit[i].clamp(lo, p95 * 1.03);
  }
  final fs = [...fit]..sort();
  final target = fs[(n * 0.95).floor()];

  // Mild overall lift for a grey cast, without clipping the highlights.
  hist.fillRange(0, 256, 0);
  var cnt = 0;
  for (var o = 0; o + 2 < rgb.length; o += 21) {
    hist[math.max(rgb[o], math.max(rgb[o + 1], rgb[o + 2]))]++;
    cnt++;
  }
  var acc = 0, top = 255;
  while (top > 1 && acc + hist[top] < cnt * 0.01) {
    acc += hist[top--];
  }
  final lift = math.min(235 / target, 250 / top).clamp(1.0, 1.3);

  for (var y = 0; y < h; y++) {
    final fy = ((y + 0.5) / h * gh - 0.5).clamp(0.0, gh - 1.0);
    final y0 = fy.floor(), y1 = math.min(y0 + 1, gh - 1);
    final ty = fy - y0;
    for (var x = 0; x < w; x++) {
      final fx = ((x + 0.5) / w * gw - 0.5).clamp(0.0, gw - 1.0);
      final x0 = fx.floor(), x1 = math.min(x0 + 1, gw - 1);
      final tx = fx - x0;
      final a = fit[y0 * gw + x0] + (fit[y0 * gw + x1] - fit[y0 * gw + x0]) * tx;
      final b = fit[y1 * gw + x0] + (fit[y1 * gw + x1] - fit[y1 * gw + x0]) * tx;
      final gain = (target / (a + (b - a) * ty)).clamp(1.0, 2.0) * lift;
      final o = (y * w + x) * 3;
      // One gain for all channels, limited so no channel clips: hue survives.
      final hi = math.max(rgb[o], math.max(rgb[o + 1], rgb[o + 2]));
      final q = hi * gain > 255 ? 255 / hi : gain;
      rgb[o] = (rgb[o] * q).round();
      rgb[o + 1] = (rgb[o + 1] * q).round();
      rgb[o + 2] = (rgb[o + 2] * q).round();
    }
  }
  return true;
}

List<double> _terms(double x, double y) => [1, x, y, x * x, x * y, y * y, x * x * x, x * x * y, x * y * y, y * y * y];

double _eval(List<double> k, double x, double y) {
  final t = _terms(x, y);
  var s = 0.0;
  for (var i = 0; i < t.length; i++) {
    s += k[i] * t[i];
  }
  return s;
}

/// Weighted least squares; a small penalty on the curved terms keeps the
/// surface calm where there is no paper.
List<double>? _fit(Float64List lum, Float64List wt, int gw, int gh) {
  const m = 10;
  final a = List.generate(m, (_) => Float64List(m + 1));
  var tw = 0.0;
  for (var i = 0; i < lum.length; i++) {
    final q = wt[i];
    if (q == 0) continue;
    tw += q;
    final t = _terms((i % gw + 0.5) / gw * 2 - 1, (i ~/ gw + 0.5) / gh * 2 - 1);
    final v = math.log(lum[i]);
    for (var r = 0; r < m; r++) {
      for (var c = 0; c < m; c++) {
        a[r][c] += q * t[r] * t[c];
      }
      a[r][m] += q * t[r] * v;
    }
  }
  for (var r = 1; r < m; r++) {
    a[r][r] += tw * (r < 3 ? 0.0005 : 0.003);
  }
  for (var c = 0; c < m; c++) {
    var p = c;
    for (var r = c + 1; r < m; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    if (a[p][c].abs() < 1e-9) return null;
    final tmp = a[p];
    a[p] = a[c];
    a[c] = tmp;
    for (var r = 0; r < m; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      for (var q = c; q <= m; q++) {
        a[r][q] -= f * a[c][q];
      }
    }
  }
  return [for (var r = 0; r < m; r++) a[r][m] / a[r][r]];
}
