import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

const agingLabels = ['0–30d', '31–60d', '61–90d', '90+d'];

/// Aging bucket index for a customer (highest non-zero bucket).
int agingBucket(Customer c) => c.aging[3] > 0
    ? 3
    : c.aging[2] > 0
        ? 2
        : c.aging[1] > 0
            ? 1
            : 0;

/// (fg, bg) color pair per aging bucket from theme tokens.
(Color, Color) bucketColors(LcColors lc, int bucket) => switch (bucket) {
      1 => (lc.gold, lc.goldbg),
      2 => (lc.warn, lc.warnbg),
      3 => (lc.bad, lc.badbg),
      _ => (lc.ok, lc.okbg),
    };

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final TextEditingController _search;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().customerQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final rows = app.customerSearchRows;

    if (!_searchFocus.hasFocus && _search.text != app.customerQuery) {
      _search.value = TextEditingValue(text: app.customerQuery, selection: TextSelection.collapsed(offset: app.customerQuery.length));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('Customers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text.rich(TextSpan(
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.mut),
                    children: [
                      const TextSpan(text: 'AR total · '),
                      TextSpan(text: '${MockData.money(app.arTotal)} BHD', style: TextStyle(color: lc.prim2, fontWeight: FontWeight.w700)),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 12),
              SearchField(hint: 'Search customers by name or area', controller: _search, onChanged: app.setCustomerQuery),
            ],
          ),
        ),
        Expanded(
          child: app.customers.isEmpty && app.dataLoading
              ? Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4))
              : rows.isEmpty
              ? Center(child: Text(app.customerQuery.isEmpty ? 'No customers' : 'No matching customers', style: TextStyle(fontSize: 14, color: lc.mut)))
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = rows[i];
              final bucket = agingBucket(c);
              final (fg, bg) = c.out == 0 ? (lc.ok, lc.okbg) : bucketColors(lc, bucket);
              final chip = c.out == 0 ? 'Clear' : agingLabels[bucket];
              return LcCard(
                onTap: () => app.openCustomer(c.id),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    _CustAvatar(name: c.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${c.area} · ${c.phone}', style: TextStyle(fontSize: 12, color: lc.mut)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [MoneyText(c.out, size: 14.5), const SizedBox(height: 4), Pill(chip, bg: bg, fg: fg)],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _CustAvatar({required this.name, this.size = 46}); // ignore: unused_element_parameter
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: lc.goldbg, shape: BoxShape.circle, border: Border.all(color: lc.gold)),
      child: Text(MockData.initials(name), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: lc.tprim)),
    );
  }
}

class CustomerScreen extends StatelessWidget {
  const CustomerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final c = app.customer;
    final outstanding = app.customerOutstanding;
    final aging = app.customerAging;
    final agingTotal = outstanding < 1 ? 1.0 : outstanding;

    Widget quick(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: LcCard(
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(icon, size: 20, color: color), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))],
              ),
            ),
          ),
        );

    return Column(
      children: [
        ScreenHeader(title: c.name, subtitle: '${c.ar} · ${c.area}', onBack: () => app.nav(Screen.customers)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
            children: [
              // Outstanding hero
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF7A1728), Color(0xFF5A101E)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: lc.prim.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OUTSTANDING BALANCE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: Colors.white.withValues(alpha: 0.65))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(MockData.money(outstanding), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
                        const SizedBox(width: 6),
                        const Text('BHD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC9A24B))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit limit ${MockData.money(c.limit)}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                        Text('Terms · Net 30', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                quick(Icons.call_outlined, 'Call', lc.icon, app.callCust),
                const SizedBox(width: 9),
                quick(Icons.chat_bubble_outline, 'WhatsApp', lc.ok, app.waCust),
                const SizedBox(width: 9),
                quick(Icons.location_on_outlined, 'Navigate', lc.icon, app.navCust),
              ]),
              const SizedBox(height: 12),
              LcCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Ageing'),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 4; i++) ...[
                      Row(
                        children: [
                          SizedBox(width: 52, child: Text(agingLabels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: [lc.ok, lc.gold, lc.warn, lc.bad][i]))),
                          const SizedBox(width: 10),
                          Expanded(child: BarTrack(fraction: aging[i] / agingTotal, color: [lc.ok, lc.gold, lc.warn, lc.bad][i], height: 8)),
                          const SizedBox(width: 10),
                          SizedBox(width: 76, child: Text(MockData.money(aging[i]), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      if (i != 3) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LcCard(
                onTap: app.goStatement,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 22, color: lc.icon),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account statement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Running balance, as-on date, share & print', style: TextStyle(fontSize: 12, color: Color(0xFF6F695C))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: lc.mut),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LcCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  _kv(context, 'Last sale', '27 Jun 2026 · INV-10441'),
                  _kv(context, 'Last payment', '01 Jul 2026 · 385.250 BHD'),
                  _kv(context, 'Salesman', 'Yousif M. · Route 4', last: true),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool last = false}) {
    final lc = context.lc;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: lc.line))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: lc.mut)),
          Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
