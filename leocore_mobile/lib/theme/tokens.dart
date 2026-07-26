import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/ar.dart';
import '../state/app_state.dart';

/// Semantic color tokens for LeoCore ERP Mobile.
///
/// Values are lifted verbatim from the design's `themeCss` light/dark maps so
/// the Flutter app matches the HTML prototype pixel-for-pixel.
@immutable
class LcColors extends ThemeExtension<LcColors> {
  final Color bg; // screen surface
  final Color card; // card surface
  final Color ink; // primary text
  final Color mut; // muted text
  final Color line; // borders / dividers
  final Color soft; // soft fill (segmented, tracks)
  final Color prim; // primary (oxblood)
  final Color prim2; // primary high
  final Color gold; // gold accent
  final Color goldbg; // gold surface
  final Color ok; // success
  final Color okbg;
  final Color warn; // warning
  final Color warnbg;
  final Color bad; // danger
  final Color badbg;
  final Color tprim; // text-on-surface primary tint
  final Color icon; // icon tint
  final List<BoxShadow> shadow;

  const LcColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.mut,
    required this.line,
    required this.soft,
    required this.prim,
    required this.prim2,
    required this.gold,
    required this.goldbg,
    required this.ok,
    required this.okbg,
    required this.warn,
    required this.warnbg,
    required this.bad,
    required this.badbg,
    required this.tprim,
    required this.icon,
    required this.shadow,
  });

  static const light = LcColors(
    bg: Color(0xFFF4F1EA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1A1A),
    mut: Color(0xFF6F695C),
    line: Color(0xFFE6E1D5),
    soft: Color(0xFFEDE8DC),
    prim: Color(0xFF6E1423),
    prim2: Color(0xFF8B1F2F),
    gold: Color(0xFFC9A24B),
    goldbg: Color(0xFFF5EDD8),
    ok: Color(0xFF1E7B4F),
    okbg: Color(0xFFE4F0E8),
    warn: Color(0xFFA05A00),
    warnbg: Color(0xFFF6ECD9),
    bad: Color(0xFFB3261E),
    badbg: Color(0xFFF7E4E2),
    tprim: Color(0xFF6E1423),
    icon: Color(0xFF6E1423),
    shadow: [
      BoxShadow(color: Color(0x0F1A1A1A), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0D1A1A1A), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );

  static const dark = LcColors(
    bg: Color(0xFF14100E),
    card: Color(0xFF1F1A17),
    ink: Color(0xFFF2EEE6),
    mut: Color(0xFFA79E8F),
    line: Color(0xFF342D27),
    soft: Color(0xFF2A2420),
    prim: Color(0xFF8B1F2F),
    prim2: Color(0xFFC4515F),
    gold: Color(0xFFD4B060),
    goldbg: Color(0xFF352B18),
    ok: Color(0xFF5FBE8C),
    okbg: Color(0xFF1D2E25),
    warn: Color(0xFFE0A94F),
    warnbg: Color(0xFF33291A),
    bad: Color(0xFFE57373),
    badbg: Color(0xFF33201E),
    tprim: Color(0xFFD8848F),
    icon: Color(0xFFC4515F),
    shadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );

  /// Category → thumbnail color (matches `catColors` in the prototype).
  static const Map<String, Color> catColors = {
    'Dairy': Color(0xFF8B1F2F),
    'Grocery': Color(0xFFA3702B),
    'Beverages': Color(0xFF2E5E4E),
    'Frozen': Color(0xFF3D5A80),
    'Household': Color(0xFF6E5A8E),
  };

  @override
  LcColors copyWith({
    Color? bg,
    Color? card,
    Color? ink,
    Color? mut,
    Color? line,
    Color? soft,
    Color? prim,
    Color? prim2,
    Color? gold,
    Color? goldbg,
    Color? ok,
    Color? okbg,
    Color? warn,
    Color? warnbg,
    Color? bad,
    Color? badbg,
    Color? tprim,
    Color? icon,
    List<BoxShadow>? shadow,
  }) {
    return LcColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      mut: mut ?? this.mut,
      line: line ?? this.line,
      soft: soft ?? this.soft,
      prim: prim ?? this.prim,
      prim2: prim2 ?? this.prim2,
      gold: gold ?? this.gold,
      goldbg: goldbg ?? this.goldbg,
      ok: ok ?? this.ok,
      okbg: okbg ?? this.okbg,
      warn: warn ?? this.warn,
      warnbg: warnbg ?? this.warnbg,
      bad: bad ?? this.bad,
      badbg: badbg ?? this.badbg,
      tprim: tprim ?? this.tprim,
      icon: icon ?? this.icon,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  LcColors lerp(ThemeExtension<LcColors>? other, double t) {
    if (other is! LcColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LcColors(
      bg: c(bg, other.bg),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      mut: c(mut, other.mut),
      line: c(line, other.line),
      soft: c(soft, other.soft),
      prim: c(prim, other.prim),
      prim2: c(prim2, other.prim2),
      gold: c(gold, other.gold),
      goldbg: c(goldbg, other.goldbg),
      ok: c(ok, other.ok),
      okbg: c(okbg, other.okbg),
      warn: c(warn, other.warn),
      warnbg: c(warnbg, other.warnbg),
      bad: c(bad, other.bad),
      badbg: c(badbg, other.badbg),
      tprim: c(tprim, other.tprim),
      icon: c(icon, other.icon),
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

/// Convenience accessor: `context.lc`.
extension LcContext on BuildContext {
  LcColors get lc => Theme.of(this).extension<LcColors>()!;
}

/// Localization accessor: `context.tr('English source string')`.
///
/// Returns the Arabic translation when the active language is Arabic and a
/// translation exists; otherwise returns the English source unchanged. The
/// language switch rebuilds the whole [MaterialApp] (locale is bound in
/// `main.dart`), so a plain `read` here is safe and re-evaluates on switch.
extension L10nContext on BuildContext {
  String tr(String en) {
    if (read<AppState>().lang == 'ar') return kArabic[en] ?? en;
    return en;
  }
}
