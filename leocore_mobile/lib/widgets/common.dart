import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';

/// The LeoCore "2×2" logo mark. [size] is the whole square edge.
class LcLogo extends StatelessWidget {
  final double size;
  final Color? bg;
  const LcLogo({super.key, this.size = 38, this.bg});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final cell = size * 0.21;
    final gap = size * 0.066;
    Widget sq(Color c, {double? s}) => Container(
          width: s ?? cell,
          height: s ?? cell,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(cell * 0.28)),
        );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? lc.prim,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Center(
        child: SizedBox(
          width: cell * 2 + gap,
          height: cell * 2 + gap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [sq(Colors.white), SizedBox(width: gap), sq(Colors.transparent)]),
              SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [sq(Colors.white), SizedBox(width: gap), sq(lc.gold, s: cell * 0.72)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wordmark "LeoCore" with the gold "Core".
class LcWordmark extends StatelessWidget {
  final double size;
  final Color inkColor;
  final Color goldColor;
  const LcWordmark({super.key, this.size = 30, required this.inkColor, required this.goldColor});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: inkColor),
        children: [
          const TextSpan(text: 'Leo'),
          TextSpan(text: 'Core', style: TextStyle(color: goldColor)),
        ],
      ),
    );
  }
}

/// Standard card container: card surface, 1px line border, 14 radius, soft shadow.
class LcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;
  const LcCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 14,
    this.onTap,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: lc.card,
        border: Border.all(color: lc.line),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? lc.shadow : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
  }
}

/// Money value with 3 decimals + tabular figures and an optional small unit.
class MoneyText extends StatelessWidget {
  final num value;
  final double size;
  final Color? color;
  final String? unit; // e.g. "BHD"
  final FontWeight weight;
  const MoneyText(this.value, {super.key, this.size = 21, this.color, this.unit, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          Money.fmt(value),
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color ?? lc.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(unit!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.mut)),
        ],
      ],
    );
  }
}

/// Small uppercase, letter-spaced, muted section label.
class SectionLabel extends StatelessWidget {
  final String text;
  final double size;
  const SectionLabel(this.text, {super.key, this.size = 12});
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: context.lc.mut,
      ),
    );
  }
}

/// A rounded 99px pill chip used for badges (stock, aging, deltas).
class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final double size;
  const Pill(this.text, {super.key, required this.bg, required this.fg, this.size = 10.5});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Stock badge derived from a product's on-hand qty.
class StockBadge extends StatelessWidget {
  final Product product;
  final double size;
  const StockBadge(this.product, {super.key, this.size = 10.5});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    // Negative = unknown (a list item whose stock the list endpoint omits).
    if (product.stock < 0) return const SizedBox.shrink();
    final level = stockLevelOf(product.stock);
    final (label, bg, fg) = switch (level) {
      StockLevel.out => ('Out of stock', lc.badbg, lc.bad),
      StockLevel.low => ('Low · ${product.stock}', lc.warnbg, lc.warn),
      StockLevel.inStock => ('In stock · ${product.stock}', lc.okbg, lc.ok),
    };
    return Pill(label, bg: bg, fg: fg, size: size);
  }
}

/// Circular icon button in a card chrome (used for back / header actions).
class IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg;
  final Color? fg;
  final Border? border;
  const IconChip(this.icon, {super.key, this.onTap, this.size = 42, this.bg, this.fg, this.border});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg ?? lc.card,
          borderRadius: BorderRadius.circular(12),
          border: border ?? Border.all(color: lc.line),
        ),
        child: Icon(icon, size: size * 0.44, color: fg ?? lc.ink),
      ),
    );
  }
}

/// Colored square thumbnail with two-letter initials (products / cart lines).
class InitialsThumb extends StatelessWidget {
  final Product product;
  final double size;
  final double fontSize;
  const InitialsThumb(this.product, {super.key, this.size = 48, this.fontSize = 14});
  @override
  Widget build(BuildContext context) {
    final color = LcColors.catColors[product.cat] ?? context.lc.prim;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.23)),
      child: Text(
        MockData.initials(product.name),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Full-width primary (oxblood) button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  const PrimaryButton(this.label, {super.key, this.onTap, this.icon, this.height = 52});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lc.prim,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: lc.prim.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 9)],
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Outlined secondary button (oxblood outline + tint text).
class OutlineButton2 extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double height;
  const OutlineButton2(this.label, {super.key, this.onTap, this.borderColor, this.height = 52});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor ?? lc.prim, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: lc.tprim)),
      ),
    );
  }
}

/// A 2-option segmented control (Details/Ledger, Low/Dead, Light/Dark, En/Ar).
class Segmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;
  const Segmented({super.key, required this.options, required this.selected, required this.onSelect, this.height = 38});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? lc.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selected == i
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: selected == i ? lc.ink : lc.mut,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable search field used on Products / Customers.
class SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const SearchField({super.key, required this.hint, this.controller, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(color: lc.card, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: lc.mut),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              controller: controller,
              style: TextStyle(fontSize: 14.5, color: lc.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14.5, color: lc.mut),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header used on drill-down screens: back chip + title/subtitle + trailing.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double topPad;
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.topPad = 60,
  });

  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconChip(Icons.arrow_back_ios_new, onTap: onBack),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: lc.mut), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// A simple track+fill progress bar (warehouse stock, aging).
class BarTrack extends StatelessWidget {
  final double fraction; // 0..1
  final Color color;
  final double height;
  const BarTrack({super.key, required this.fraction, required this.color, this.height = 6});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: lc.soft,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1),
          child: Container(color: color),
        ),
      ),
    );
  }
}
