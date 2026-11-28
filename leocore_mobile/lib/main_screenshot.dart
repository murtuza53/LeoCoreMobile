// Debug-only entry for taking screenshots of real screens with demo data,
// without signing in to a server. NOT used by release builds (which build
// lib/main.dart). Run:
//   flutter run -t lib/main_screenshot.dart --dart-define=SHOT=count
// SHOT: count | count_search | products | products_search | product | count_counted | scan_edit;  QUERY: the search text
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'screens/scan_edit_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const shot = String.fromEnvironment('SHOT', defaultValue: 'count');
  const query = String.fromEnvironment('QUERY', defaultValue: 'sup-41');
  runApp(LeoCoreApp(create: () {
    final s = AppState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      switch (shot) {
        case 'products':
        case 'products_search':
          s.nav(Screen.products);
          if (shot == 'products_search') s.setQuery(query);
        case 'product':
          s.nav(Screen.products);
          s.openProduct(2);
        case 'scan_edit':
          _openScanEdit(s);
        default:
          s.startCount();
          s.nav(Screen.count);
          if (shot == 'count_search') s.setCountQuery(query);
          if (shot == 'count_counted') s.setCountOnlyCounted(true);
      }
    });
    return s;
  }));
}

/// The Adjust pages screen with two made-up scanned pages (a yellow slip with a
/// shadow, and a white page), as if they came from the scanner.
Future<void> _openScanEdit(AppState s) async {
  final dir = await getTemporaryDirectory();
  final paths = <String>[];
  for (final yellow in [true, false]) {
    const w = 600, h = 800;
    final im = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final shade = 1 - 0.35 * math.max(0, 1 - (x + y) / 700); // shadow in the top-left corner
        final r = (yellow ? 246 : 236) * shade, g = (yellow ? 228 : 234) * shade, b = (yellow ? 150 : 228) * shade;
        im.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }
    // "text": dark bars
    final rnd = math.Random(yellow ? 1 : 2);
    for (var line = 0; line < 22; line++) {
      final y0 = 80 + line * 30;
      var x = 55;
      while (x < 525) {
        final len = 20 + rnd.nextInt(75);
        img.fillRect(im, x1: x, y1: y0, x2: math.min(x + len, 545), y2: y0 + 9, color: img.ColorRgb8(40, 40, 60));
        x += len + 12;
      }
    }
    img.fillRect(im, x1: 55, y1: 30, x2: 300, y2: 55, color: img.ColorRgb8(150, 30, 40)); // red heading
    final f = File('${dir.path}/shot_page_${paths.length + 1}.jpg');
    await f.writeAsBytes(img.encodeJpg(im, quality: 85));
    paths.add(f.path);
  }
  s.navigatorKey.currentState?.push(MaterialPageRoute<List<String>>(
    fullscreenDialog: true,
    builder: (_) => ScanEditScreen(pages: paths, initialTone: s.scanTone, onToneChosen: s.setScanTone),
  ));
}
