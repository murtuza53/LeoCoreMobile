import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';

/// Bottom navigation bar with a centered floating Scan FAB — matches the
/// prototype's Home / Products / (Scan) / Customers / More layout.
class LcBottomNav extends StatelessWidget {
  const LcBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final s = app.screen;
    // Clear the Android system navigation bar (gesture pill / 3-button bar).
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Color c(bool on) => on ? lc.tprim : lc.mut;

    Widget item(IconData icon, String label, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 23, color: c(on)),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c(on))),
                ],
              ),
            ),
          ),
        );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: lc.card,
            border: Border(top: BorderSide(color: lc.line)),
          ),
          padding: EdgeInsets.fromLTRB(6, 8, 6, 10 + bottomInset),
          child: Row(
            children: [
              item(Icons.home_outlined, 'Home', s == Screen.home, () => app.nav(Screen.home)),
              item(Icons.inventory_2_outlined, 'Products', s == Screen.products, () => app.nav(Screen.products)),
              const SizedBox(width: 72),
              item(Icons.people_outline, 'Customers', s == Screen.customers, () => app.nav(Screen.customers)),
              item(Icons.grid_view_outlined, 'More', s == Screen.more, () => app.nav(Screen.more)),
            ],
          ),
        ),
        Positioned(
          top: -26,
          child: GestureDetector(
            onTap: app.openScan,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: lc.prim,
                shape: BoxShape.circle,
                border: Border.all(color: lc.bg, width: 5),
                boxShadow: [BoxShadow(color: lc.prim.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.qr_code_scanner, color: lc.gold, size: 26),
            ),
          ),
        ),
      ],
    );
  }
}

/// Amber offline banner shown when `offline` is on.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lc.warnbg,
        border: Border.all(color: lc.warn),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: lc.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — 3 transactions queued, will sync automatically',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: lc.warn),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating toast pill anchored above the bottom nav.
class LcToast extends StatelessWidget {
  final String message;
  const LcToast(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 118,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF26211D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 16, color: Color(0xFFC9A24B)),
                const SizedBox(width: 9),
                Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF2EEE6))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
