import 'package:flutter_test/flutter_test.dart';

import 'package:leocore_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LeoCoreApp());
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
  });
}
