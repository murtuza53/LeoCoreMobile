import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final from in [Screen.count, Screen.invoice, Screen.quotation, Screen.products]) {
    test('closing the scanner returns to ${from.name}', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final s = AppState(); // demo mode
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (from == Screen.count) s.startCount();
      s.nav(from);
      expect(s.screen, from);

      s.openScan();
      expect(s.screen, Screen.scan);
      s.handleSystemBack(); // phone back
      expect(s.screen, from);

      s.openScan();
      s.closeScan(); // the ✕ button
      expect(s.screen, from);
    });
  }
}
