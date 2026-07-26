import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _server;
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _serverFocus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _user = TextEditingController(text: app.loginUser);
    _pass = TextEditingController(text: app.loginPass);
    _server = TextEditingController(text: app.serverUrl);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _server.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _serverFocus.dispose();
    super.dispose();
  }

  /// Keep a field in sync with state when the user isn't editing it — so a
  /// logout (blank credentials) or a restored server address reflects here.
  void _sync(TextEditingController c, FocusNode f, String v) {
    if (!f.hasFocus && c.text != v) {
      c.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;

    _sync(_user, _userFocus, app.loginUser);
    _sync(_pass, _passFocus, app.loginPass);
    _sync(_server, _serverFocus, app.serverUrl);

    InputDecoration dec({String? hint}) => InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: lc.mut),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: lc.bg,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: lc.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: lc.prim2)),
        );

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: lc.mut)),
        );

    return Container(
      color: lc.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Oxblood branded header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 84, 28, 64),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF7A1728),
                  Color(0xFF6E1423),
                  Color(0xFF480C17)
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _WhiteLogo(),
                    SizedBox(width: 14),
                    LcWordmark(
                        inkColor: Colors.white, goldColor: Color(0xFFC9A24B)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                    app.sessionLocked
                        ? context.tr('ERP Mobile · Locked — unlock with your fingerprint')
                        : context.tr('ERP Mobile · Sign in to your workspace'),
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -36),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  LcCard(
                    shadow: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (app.loginErr || app.loginErrMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                color: lc.badbg,
                                border: Border.all(color: lc.bad),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: lc.bad),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: lc.bad),
                                      children: [
                                        TextSpan(
                                            text: context.tr('Sign-in failed. '),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        TextSpan(
                                            text: app.loginErrMsg ??
                                                context.tr('Check your password or contact your administrator.')),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        label(context.tr('Username')),
                        TextField(
                            controller: _user,
                            focusNode: _userFocus,
                            onChanged: app.setLoginUser,
                            decoration: dec(),
                            style: TextStyle(fontSize: 15, color: lc.ink)),
                        const SizedBox(height: 16),
                        label(context.tr('Password')),
                        TextField(
                          controller: _pass,
                          focusNode: _passFocus,
                          onChanged: app.setLoginPass,
                          obscureText: _obscure,
                          decoration: dec(hint: '••••••••').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: lc.mut,
                              ),
                              tooltip: _obscure ? context.tr('Show password') : context.tr('Hide password'),
                            ),
                          ),
                          style: TextStyle(fontSize: 15, color: lc.ink),
                        ),
                        const SizedBox(height: 16),
                        label(context.tr('Server location')),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                              color: lc.bg,
                              border: Border.all(color: lc.line),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Icon(Icons.dns_outlined,
                                  size: 18, color: lc.icon),
                              const SizedBox(width: 9),
                              Expanded(
                                child: TextField(
                                  controller: _server,
                                  focusNode: _serverFocus,
                                  onChanged: app.setServerUrl,
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: 'https://erp.yourcompany.bh'),
                                  style: TextStyle(fontSize: 15, color: lc.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: app.toggleKeep,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.tr('Keep me signed in'),
                                    style:
                                        TextStyle(fontSize: 14, color: lc.ink)),
                                _Toggle(on: app.keep, onColor: lc.ok),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        app.loggingIn
                            ? Container(
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: lc.prim,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: Colors.white)),
                              )
                            : PrimaryButton(context.tr('Sign in'), onTap: app.doLogin),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Divider(color: lc.line, height: 1)),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(context.tr('or'),
                                  style:
                                      TextStyle(fontSize: 12, color: lc.mut))),
                          Expanded(child: Divider(color: lc.line, height: 1)),
                        ]),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: app.doBiometric,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: lc.gold, width: 1.5)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fingerprint,
                                    color: lc.gold, size: 24),
                                const SizedBox(width: 10),
                                Text(context.tr('Unlock with fingerprint'),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: lc.ink)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                      child: Text('LeoCore ERP · v2.4.1 · leocoreerp.seksolution.com',
                          style: TextStyle(fontSize: 12, color: lc.mut))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteLogo extends StatelessWidget {
  const _WhiteLogo();
  @override
  Widget build(BuildContext context) {
    Widget sq(Color c, {double s = 15}) => Container(
        width: s,
        height: s,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
    return SizedBox(
      width: 34,
      height: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            sq(Colors.white),
            const SizedBox(width: 4),
            sq(Colors.transparent)
          ]),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              sq(Colors.white),
              const SizedBox(width: 4),
              sq(const Color(0xFFC9A24B), s: 12)
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill toggle switch matching the prototype's custom knob.
class _Toggle extends StatelessWidget {
  final bool on;
  final Color onColor;
  const _Toggle({required this.on, required this.onColor});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: on ? onColor : const Color(0xFFC8C2B4),
          borderRadius: BorderRadius.circular(99)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 3,
                  offset: const Offset(0, 1))
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposed so Settings can reuse the same toggle look.
class LcToggle extends StatelessWidget {
  final bool on;
  final Color onColor;
  const LcToggle({super.key, required this.on, required this.onColor});
  @override
  Widget build(BuildContext context) => _Toggle(on: on, onColor: onColor);
}
