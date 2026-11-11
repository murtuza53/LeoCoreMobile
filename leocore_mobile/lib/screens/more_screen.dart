import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // The role's pages (AppState.morePages — same table as the Home grid).
    final items = <(IconData, String, String, VoidCallback)>[
      for (final pg in app.morePages) (pg.icon, context.tr(pg.more!), context.tr(pg.subtitle), pg.moreTap!),
      (Icons.settings_outlined, context.tr('Settings'), context.tr('Language, theme, devices, role'), () => app.nav(Screen.settings)),
    ];
    if (app.appVersion.isEmpty) app.loadAppVersion();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
          child: Text(context.tr('More'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            children: [
              for (final it in items) ...[
                _MoreRow(icon: it.$1, title: it.$2, subtitle: it.$3, onTap: it.$4),
                const SizedBox(height: 8),
              ],
              _MoreRow(
                icon: Icons.system_update_outlined,
                title: context.tr('Check for updates'),
                subtitle: app.updateAvailable
                    ? context.tr('A new version is available — tap to update')
                    : '${context.tr('Version')} ${app.appVersion}',
                onTap: app.checkForUpdateNow,
                busy: app.checkingUpdate,
                highlight: app.updateAvailable,
              ),
              const SizedBox(height: 16),
              _SignOutButton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lc = context.lc;
    return GestureDetector(
      onTap: app.doLogout,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: lc.bad, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, size: 18, color: lc.bad),
            const SizedBox(width: 8),
            Text(context.tr('Sign out'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: lc.bad)),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;
  final bool highlight;
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return LcCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: highlight ? lc.prim : lc.icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: highlight ? lc.prim : lc.mut,
                      fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (busy)
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: lc.prim))
          else
            Icon(Icons.chevron_right, size: 15, color: lc.mut),
        ],
      ),
    );
  }
}
