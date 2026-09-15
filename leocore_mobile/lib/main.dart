import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'shell/app_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system bars (Android 15 / SDK 35 enforces edge-to-edge).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LeoCoreApp());
}

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
    final lang = context.select<AppState, String>((s) => s.lang);
    final lc = isDark ? LcColors.dark : LcColors.light;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    // Transparent system bars so content draws edge-to-edge; icon brightness
    // follows the theme. (Colours are transparent rather than set to a bar
    // colour, which is deprecated/no-op on Android 15.)
    SystemChrome.setSystemUIOverlayStyle(
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
    );

    return MaterialApp(
      title: 'LeoCore ERP Mobile',
      debugShowCheckedModeBanner: false,
      navigatorKey: context.read<AppState>().navigatorKey,
      theme: buildTheme(lc, brightness),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: Locale(lang),
      home: const AppShell(),
    );
  }
}
