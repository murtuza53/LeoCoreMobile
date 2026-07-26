import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Suppliers list with type-to-search; tapping opens the supplier statement.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().supplierQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final rows = app.supplierRows;

    return Column(
      children: [
        ScreenHeader(title: context.tr('Suppliers'), onBack: () => app.nav(Screen.home)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: SearchField(hint: context.tr('Search suppliers'), controller: _search, onChanged: app.setSupplierQuery),
        ),
        Expanded(
          child: app.suppliersLoading && rows.isEmpty
              ? Center(child: CircularProgressIndicator(color: lc.prim, strokeWidth: 2.4))
              : rows.isEmpty
                  ? Center(child: Text(app.demoMode ? context.tr('Suppliers are available on live sign-in') : context.tr('No suppliers'), style: TextStyle(fontSize: 14, color: lc.mut)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 60),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = rows[i];
                        return LcCard(
                          onTap: () => app.openSupplierStatement(s.id),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: lc.soft, borderRadius: BorderRadius.circular(11)),
                                child: Icon(Icons.local_shipping_outlined, size: 20, color: lc.icon),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    if (s.area.isNotEmpty || s.phone.isNotEmpty)
                                      Text([s.area, s.phone].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12, color: lc.mut)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(children: [
                                Text(context.tr('Statement'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.tprim)),
                                Icon(Icons.chevron_right, size: 18, color: lc.mut),
                              ]),
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
