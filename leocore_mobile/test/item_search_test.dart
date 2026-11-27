import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/theme/tokens.dart';
import 'package:leocore_mobile/utils/item_search.dart';
import 'package:leocore_mobile/widgets/common.dart';

void main() {
  const wheel = ['Front Wheel 10in Black', 'CST-0042', '6291234500017', 'EM-ECH-125'];

  group('itemMatches (same rule as the server)', () {
    test('a word matches anywhere in any field, ignoring case', () {
      expect(itemMatches('wheel', wheel), isTrue); // *wheel*
      expect(itemMatches('HEEL', wheel), isTrue);
      expect(itemMatches('0042', wheel), isTrue); // item code
      expect(itemMatches('ech-12', wheel), isTrue); // supplier code
      expect(itemMatches('45000', wheel), isTrue); // barcode
      expect(itemMatches('castor', wheel), isFalse);
    });

    test('every word must match, in any order and any field', () {
      expect(itemMatches('black wheel', wheel), isTrue);
      expect(itemMatches('wheel ECH', wheel), isTrue);
      expect(itemMatches('wheel red', wheel), isFalse);
    });

    test('* works inside a word; outer * and blanks are ignored', () {
      expect(itemMatches('wh*l', wheel), isTrue);
      expect(itemMatches('*wheel*', wheel), isTrue);
      expect(itemMatches('em*125', wheel), isTrue);
      expect(itemMatches('w*z', wheel), isFalse);
      expect(itemMatches('   ', wheel), isTrue);
      expect(itemMatches('*', wheel), isTrue);
    });

    test('regex characters are literal', () {
      expect(itemMatches('10in.', wheel), isFalse);
      expect(itemMatches('(', ['a(b']), isTrue);
    });
  });

  testWidgets('ItemCodes: one line, three colours, duplicates dropped, shrinks to fit', (tester) async {
    Future<void> show(Widget w, double width) => tester.pumpWidget(MaterialApp(
          theme: ThemeData(extensions: const [LcColors.light]),
          home: Scaffold(body: Center(child: SizedBox(width: width, child: w))),
        ));

    await show(const ItemCodes(code: 'CST-0042', supplierCode: 'EM-ECH-125', barcode: '6291234500017'), 400);
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final texts = rich.children!.cast<TextSpan>().where((s) => !s.text!.contains('·')).toList();
    expect(texts.map((s) => s.text), ['CST-0042', 'EM-ECH-125', '6291234500017']);
    expect(texts.map((s) => s.style!.color).toSet().length, 3);

    await show(const ItemCodes(code: '35003420', supplierCode: '35003420', barcode: '35003420'), 400);
    final one = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    expect(one.children!.length, 1);

    // Very narrow row: still one line, scaled down, no overflow.
    await show(const ItemCodes(code: 'CST-0042-LONG', supplierCode: 'EM-ECH-125-XL', barcode: '6291234500017'), 120);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ItemCodes)).height, lessThan(20));
    expect(tester.getSize(find.byType(ItemCodes)).width, lessThanOrEqualTo(120));
  });
}
