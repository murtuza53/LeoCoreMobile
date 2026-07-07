import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'shell/app_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() => runApp(const LeoCoreApp());

/// Root widget — owns the [AppState] store so the app is self-contained
/// (both `main()` and widget tests can mount it directly).
class LeoCoreApp extends StatelessWidget {
  const LeoCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const _MaterialRoot(),
    );
  }
}

class _MaterialRoot extends StatelessWidget {
  const _MaterialRoot();

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppState, bool>((s) => s.isDark);
    final lc = isDark ? LcColors.dark : LcColors.light;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return MaterialApp(
      title: 'LeoCore ERP Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lc, brightness),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: const AppShell(),
    );
  }
}
