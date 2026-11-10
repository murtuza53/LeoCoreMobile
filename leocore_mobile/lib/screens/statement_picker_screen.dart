import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/paged_list_view.dart';

/// "Account statement" entry point from Home — pick a customer by typing.
class StatementPickerScreen extends StatefulWidget {
  const StatementPickerScreen({super.key});
  @override
  State<StatementPickerScreen> createState() => _StatementPickerScreenState();
}

class _StatementPickerScreenState extends State<StatementPickerScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppState>().statementQuery);
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
    final list = app.statementList;
    list.ensureLoaded();

    return Column(
      children: [
        ScreenHeader(title: context.tr('Account statement'), subtitle: context.tr('Choose a customer'), onBack: () => app.nav(Screen.home)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(children: [
            SearchField(
              hint: context.tr('Search name, phone, VAT number or ID'),
              controller: _search,
              onChanged: app.setStatementQuery,
            ),
            const SizedBox(height: 10),
            PartyFilterChips(
              hideZero: app.statementFilter.hideZero,
              byBalance: app.statementFilter.byBalance,
              onHideZero: () => app.toggleHideZero(app.statementFilter, list),
              onByBalance: () => app.toggleByBalance(app.statementFilter, list),
            ),
          ]),
        ),
        Expanded(
          child: PagedListView<Customer>(
            list: list,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
            emptyText: app.statementQuery.isEmpty ? 'No customers' : 'No matching customers',
            itemBuilder: (_, c) {
              return LcCard(
                onTap: () => app.openStatementFor(c.id),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: lc.goldbg, shape: BoxShape.circle, border: Border.all(color: lc.gold)),
                      child: Text(MockData.initials(c.name), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: lc.tprim)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (c.area.isNotEmpty) Text(c.area, style: TextStyle(fontSize: 12, color: lc.mut)),
                        ],
                      ),
                    ),
                    if (c.out > 0) MoneyText(c.out, size: 13.5),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 18, color: lc.mut),
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
