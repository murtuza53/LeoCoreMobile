import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'login_screen.dart' show LcToggle;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    Widget miniSeg(List<(String, bool, VoidCallback)> options) => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                GestureDetector(
                  onTap: o.$3,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.$2 ? lc.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: o.$2 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1))] : null,
                    ),
                    child: Text(o.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: o.$2 ? lc.ink : lc.mut)),
                  ),
                ),
            ],
          ),
        );

    return Column(
      children: [
        ScreenHeader(title: context.tr('Settings'), onBack: () => app.nav(Screen.more)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
            children: [
              // Profile card
              LcCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: lc.goldbg, shape: BoxShape.circle, border: Border.all(color: lc.gold)),
                      child: Text(app.userInitials, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: lc.tprim)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.userName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                          Text(app.userHandle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: lc.mut)),
                        ],
                      ),
                    ),
                    Pill(app.userRoleLabel, bg: lc.goldbg, fg: lc.tprim, size: 11),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Preferences
              LcCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    _prefRow(context, context.tr('Language'), trailing: miniSeg([
                      ('English', app.lang == 'en', () => app.pickLang('en')),
                      ('العربية', app.lang == 'ar', () => app.pickLang('ar')),
                    ])),
                    _divider(lc),
                    _prefRow(context, context.tr('Theme'), trailing: miniSeg([
                      ('☀ ${context.tr('Light')}', !app.isDark, app.pickLight),
                      ('☾ ${context.tr('Dark')}', app.isDark, app.pickDark),
                    ])),
                    _divider(lc),
                    GestureDetector(
                      onTap: app.toggleBio,
                      behavior: HitTestBehavior.opaque,
                      child: _toggleRow(
                          context,
                          context.tr('Fingerprint unlock'),
                          app.biometricAvailable
                              ? context.tr('Require your fingerprint to reopen the app')
                              : context.tr('No fingerprint enrolled on this device'),
                          app.biometrics,
                          lc.ok),
                    ),
                    _divider(lc),
                    GestureDetector(
                      onTap: app.toggleOffline,
                      behavior: HitTestBehavior.opaque,
                      child: _toggleRow(context, context.tr('Simulate offline mode'), context.tr('Shows the offline banner & sync queue'), app.offline, lc.warn, last: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Roles / permissions
              LcCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: app.demoMode
                      ? [
                          SectionLabel(context.tr('Demo role (permissions)')),
                          const SizedBox(height: 10),
                          Row(children: [
                            _roleBtn(context, context.tr('Manager'), app.role == Role.manager, () => app.pickRole(Role.manager)),
                            const SizedBox(width: 8),
                            _roleBtn(context, context.tr('Sales Rep'), app.role == Role.salesRep, () => app.pickRole(Role.salesRep)),
                            const SizedBox(width: 8),
                            _roleBtn(context, context.tr('Storekeeper'), app.role == Role.storekeeper, () => app.pickRole(Role.storekeeper)),
                          ]),
                          const SizedBox(height: 10),
                          Text(context.tr('Home workspace tiles appear only if the role has permission — try switching.'), style: TextStyle(fontSize: 11.5, height: 1.5, color: lc.mut)),
                        ]
                      : [
                          SectionLabel(context.tr('Roles & access')),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final r in (app.me?.roles ?? const <String>[]))
                                Pill(r, bg: lc.goldbg, fg: lc.tprim, size: 11.5),
                              Pill(app.canWrite ? context.tr('read · write') : context.tr('read only'), bg: lc.soft, fg: lc.mut, size: 11.5),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(context.tr('Access is granted server-side per role; the app only shows what your account permits.'), style: TextStyle(fontSize: 11.5, height: 1.5, color: lc.mut)),
                        ],
                ),
              ),
              const SizedBox(height: 12),
              // Registered devices
              LcCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: SectionLabel(context.tr('Registered devices'))),
                    if (app.demoMode) ...[
                      _deviceRow(context, 'iPhone 15 · Yousif', 'This device · last sync 2 min ago', active: true),
                      _divider(lc),
                      _deviceRow(context, 'Zebra TC26 · Store', 'Last sync 3 days ago', active: false, last: true),
                    ] else
                      _deviceRow(context, app.deviceLabel, context.tr('This device · signed in'), active: true, last: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Rate the app
              LcCard(
                onTap: app.rateApp,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.star_rate_rounded, size: 22, color: lc.gold),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Rate LeoCore ERP'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(context.tr('Enjoying the app? Leave a review'), style: const TextStyle(fontSize: 12, color: Color(0xFF6F695C))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: lc.mut),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: app.doLogout,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: lc.bad, width: 1.5)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, size: 18, color: lc.bad),
                      const SizedBox(width: 8),
                      Text(context.tr('Sign out'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: lc.bad)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(LcColors lc) => Divider(height: 1, color: lc.line);

  Widget _prefRow(BuildContext context, String label, {required Widget trailing}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing],
      ),
    );
  }

  Widget _toggleRow(BuildContext context, String title, String subtitle, bool on, Color color, {bool last = false}) {
    final lc = context.lc;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: lc.mut)),
              ],
            ),
          ),
          LcToggle(on: on, onColor: color),
        ],
      ),
    );
  }

  Widget _roleBtn(BuildContext context, String label, bool on, VoidCallback onTap) {
    final lc = context.lc;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? lc.prim : lc.card, border: Border.all(color: on ? lc.prim : lc.line), borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : lc.ink)),
        ),
      ),
    );
  }

  Widget _deviceRow(BuildContext context, String name, String meta, {required bool active, bool last = false}) {
    final lc = context.lc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(Icons.smartphone, size: 19, color: active ? lc.icon : lc.mut),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(meta, style: TextStyle(fontSize: 11.5, color: lc.mut)),
              ],
            ),
          ),
          if (active)
            Pill(context.tr('Active'), bg: lc.okbg, fg: lc.ok)
          else
            Text(context.tr('Revoke'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.bad)),
        ],
      ),
    );
  }
}
