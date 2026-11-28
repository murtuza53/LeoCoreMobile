import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removeCounted takes an item off the sheet, other items stay', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final s = AppState(); // demo mode
    await Future<void>.delayed(const Duration(milliseconds: 50));
    s.startCount(); // the demo sheet starts with some items counted
    s.setCount(1, 5);
    s.setCount(3, 7);
    final n = s.countedLines;
    expect(n, greaterThanOrEqualTo(2));
    s.countDirty = false;

    s.removeCounted(1);
    expect(s.countedLines, n - 1);
    expect(s.countValue(1), isNull);
    expect(s.countValue(3), isNotNull);
    expect(s.countDirty, isTrue);

    s.removeCounted(1); // already gone: nothing happens
    expect(s.countedLines, n - 1);
  });
}
