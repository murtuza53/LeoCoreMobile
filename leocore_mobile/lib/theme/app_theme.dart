import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the LeoCore [ThemeData] for a given [LcColors] palette.
///
/// Type: IBM Plex Sans, tabular figures for money (applied per-widget via
/// [MoneyText]). Radii: 14 cards · 12 buttons · 99 chips. 4-pt spacing grid.
ThemeData buildTheme(LcColors lc, Brightness brightness) {
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

  final scheme = ColorScheme.fromSeed(
    seedColor: lc.prim,
    brightness: brightness,
  ).copyWith(
    primary: lc.prim,
    surface: lc.bg,
    onSurface: lc.ink,
    error: lc.bad,
  );

  final textTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
    bodyColor: lc.ink,
    displayColor: lc.ink,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: lc.bg,
    canvasColor: lc.bg,
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    extensions: [lc],
    dividerColor: lc.line,
    iconTheme: IconThemeData(color: lc.ink),
  );
}
