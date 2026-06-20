import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'edit_expense_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // #10 fix — search is local, does NOT pollute provider state
  final _searchCtrl = TextEditingController();
  String _localSearch = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Expense> _applySearch(List<Expense> list) {
    if (_localSearch.isEmpty) return list;
    final q = _localSearch.toLowerCase();
    return list.where((e) =>
      e.name.toLowerCase().contains(q) ||
      e.category.toLowerCase().contains(q) ||
      e.upiApp.toLowerCase().contains(q) ||
      (e.note?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<ExpenseProvider>();
    final list = _applySearch(p.filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 16),
              onChanged: (v) => setState(() => _localSearch = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search payee, category…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _localSearch.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _localSearch = ''); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: 'Sort',
            onSelected: p.setSort,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date',   child: Text('Sort by date')),
              PopupMenuItem(value: 'amount', child: Text('Sort by amount')),
              PopupMenuItem(value: 'payee',  child: Text('Sort by payee')),
            ],
          ),
        ],
      ),

      // Filter chips
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            for (final cat in ['All', ...kCategories])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat, style: const TextStyle(fontSize: 12)),
                  selected: p.filterCategory == cat,
                  onSelected: (_) => p.setFilter(cat),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.primary,
                ),
              ),
          ]),
        ),

        // #17 pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: p.load,
            child: p.loading
                ? const Center(child: CircularProgressIndicator())
                : p.error != null && list.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF888780)),
                        const SizedBox(height: 12),
                        Text(p.error!, style: const TextStyle(color: Color(0xFF888780))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(onPressed: p.load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                      ]))
                    : list.isEmpty
                        ? const EmptyState(message: 'No transactions found')
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(height: 0.5),
                            itemBuilder: (_, i) {
                              final e = list[i];
                              return TxnTile(
                                expense: e,
                                // Edit button (#14)
                                onEdit: e.id != null ? () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => EditExpenseScreen(expense: e)));
                                } : null,
                                // #6 fix — show error on delete failure
                                onDelete: e.id != null ? () async {
                                  final err = await p.deleteExpense(e.id!);
                                  if (err != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
                                    );
                                  }
                                } : null,
                              );
                            },
                          ),
          ),
        ),

        // Summary footer
        if (list.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: Row(children: [
              Text('${list.length} transactions', style: const TextStyle(fontSize: 12, color: const Color(0xFF888780))),
              const Spacer(),
              Text('Total: ${fmtAmt(list.where((e) => e.type == 'debit').fold(0.0, (s, e) => s + e.amount))}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}
