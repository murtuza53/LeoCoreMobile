import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:leocore_mobile/screens/scan_edit_screen.dart';
import 'package:leocore_mobile/state/app_state.dart';
import 'package:leocore_mobile/theme/tokens.dart';
import 'package:leocore_mobile/utils/scan_enhance.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Adjust pages fits a small phone; previews render; switch and fixes work', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('scan');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final im = img.Image(width: 300, height: 420)..clear(img.ColorRgb8(230, 215, 120));
    final pages = [
      for (var i = 0; i < 3; i++) (File('${dir.path}/$i.jpg')..writeAsBytesSync(img.encodeJpg(im))).path,
    ];
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
    }

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        theme: ThemeData(extensions: const [LcColors.light]),
        home: ScanEditScreen(pages: pages, initialTone: ScanTone.originalPlus, onToneChosen: (_) {}),
      ),
    ));
    await settle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final s in ['Original+', 'Shadows', 'Edges', 'Straighten', 'This page', 'All pages', 'Create PDF']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    await tester.tap(find.text('All pages'));
    await tester.pump();
    await tester.tap(find.text('Auto colour'));
    await settle();
    expect(find.byIcon(Icons.auto_fix_high), findsNWidgets(4)); // chip + 3 thumbnails
    await tester.tap(find.text('This page'));
    await tester.pump();
    await tester.tap(find.text('Original+'));
    await settle();
    expect(find.byIcon(Icons.auto_fix_high), findsNWidgets(3)); // page 1 differs
    await tester.tap(find.text('Edges'));
    await settle();
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
