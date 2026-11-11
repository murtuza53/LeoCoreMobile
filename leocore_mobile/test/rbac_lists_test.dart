import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leocore_mobile/api/api_client.dart';
import 'package:leocore_mobile/models/permissions.dart';
import 'package:leocore_mobile/state/paged_list.dart';

void main() {
  group('PagedList', () {
    test('a refused list is fetched once — the next builds do not retry it', () async {
      var calls = 0;
      final list = PagedList<int>((page, size, search) async {
        calls++;
        throw const ApiException('FORBIDDEN', 'Forbidden', status: 403);
      }, onChanged: () {});

      list.ensureLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // What every rebuild of the screen does:
      for (var i = 0; i < 5; i++) {
        list.ensureLoaded();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(calls, 1);
      expect(list.forbidden, isTrue);
      expect(list.loaded, isTrue);
      expect(list.error, isNotNull);

      // Pull-to-refresh still tries again.
      await list.refresh();
      expect(calls, 2);
    });

    test('an offline failure is not retried by rebuilds either', () async {
      var calls = 0;
      final list = PagedList<int>((page, size, search) async {
        calls++;
        throw Exception('offline');
      }, onChanged: () {});
      list.ensureLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      list.ensureLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 1);
      expect(list.forbidden, isFalse);
    });
  });

  group('MobilePermissions', () {
    final docsOnly = {
      'version': 2,
      'items': [
        {'id': 'documents', 'feature': 'MobileDocuments'}
      ],
      'permissions': {
        'MobileAccess': {'view': true},
        'MobileDocuments': {'view': true, 'edit': true, 'delete': false},
        'MobileCustomers': {'view': false},
      },
    };

    test('a documents-only role grants documents and nothing else', () {
      final p = MobilePermissions.fromMenu(docsOnly);
      expect(p.known, isTrue);
      expect(p.of(Feat.documents).view, isTrue);
      expect(p.of(Feat.documents).edit, isTrue);
      expect(p.of(Feat.customers).view, isFalse);
      expect(p.of(Feat.products).view, isFalse); // absent → none
      expect(p.of(Feat.dashboard).view, isFalse);
    });

    test('the copy saved on the phone reads back the same rights', () {
      final p = MobilePermissions.fromMenu(docsOnly);
      final back = MobilePermissions.fromMenu(jsonDecode(jsonEncode(p.toJson())) as Map);
      expect(back.known, isTrue);
      expect(back.of(Feat.documents).edit, isTrue);
      expect(back.of(Feat.documents).delete, isFalse);
      expect(back.of(Feat.customers).view, isFalse);
    });

    test('a role without Mobile Access (empty map) is known and grants nothing', () {
      final p = MobilePermissions.fromMenu(const {'permissions': {}});
      expect(p.known, isTrue);
      expect(p.of(Feat.documents).view, isFalse);
    });
  });
}
