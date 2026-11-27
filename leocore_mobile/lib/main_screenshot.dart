// Debug-only entry for taking screenshots of real screens with demo data,
// without signing in to a server. NOT used by release builds (which build
// lib/main.dart). Run:
//   flutter run -t lib/main_screenshot.dart --dart-define=SHOT=count
// SHOT: count | count_search | products | products_search;  QUERY: the search text
import 'package:flutter/material.dart';

import 'main.dart';
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
        default:
          s.startCount();
          s.nav(Screen.count);
          if (shot == 'count_search') s.setCountQuery(query);
      }
    });
    return s;
  }));
}
