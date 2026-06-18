import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  // #1 — Edit budget limit dialog
  Future<void> _showEditBudgetDialog(BuildContext context, ExpenseProvider p, String category, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $category budget'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            style: const TextStyle(fontSize: 16),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Monthly limit (₹)', prefixText: '₹ '),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final v = double.parse(ctrl.text);
                p.setBudget(category, v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // #2 — Update goal saved amount dialog
  Future<void> _showUpdateGoalDialog(BuildContext context, ExpenseProvider p, int idx) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${p.goals[idx].name}"'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            style: const TextStyle(fontSize: 16),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Amount saved (₹)', prefixText: '₹ '),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final v = double.parse(ctrl.text);
                p.updateGoalSaved(idx, v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // #3 — Add savings goal dialog
  Future<void> _showAddGoalDialog(BuildContext context, ExpenseProvider p) async {
    final nameCtrl   = TextEditingController();
    final targetCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New savings goal'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: 16),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Goal name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Goal name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: targetCtrl,
              style: const TextStyle(fontSize: 16),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target amount (₹)', prefixText: '₹ '),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid target amount greater than 0';
                return null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final name   = nameCtrl.text.trim();
                final target = double.parse(targetCtrl.text);
                p.addGoal(name, target);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameCtrl.dispose(); targetCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<ExpenseProvider>();
    final cats = p.categoryTotals;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets & goals')),
      body: RefreshIndicator( // #17
        onRefresh: p.load,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // ── Budget progress ───────────────────────────────
          const SectionHeader(title: 'MONTHLY LIMITS'),
          // #1 — long press or edit icon on each card to edit limit
          ...p.budgets.entries.map((entry) {
            final spent  = cats[entry.key] ?? 0.0;
            final limit  = entry.value;
            final pct    = (spent / limit).clamp(0.0, 1.0);
            final col    = pct >= 0.9 ? AppTheme.danger : pct >= 0.7 ? AppTheme.warning : AppTheme.success;
            final catCol = AppColors.category[entry.key] ?? const Color(0xFF888780);
            final ico    = AppIcons.category[entry.key]  ?? Icons.more_horiz;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Icon(ico, size: 18, color: catCol),
                    const SizedBox(width: 8),
                    Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: fmtAmt(spent), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: col)),
                      TextSpan(text: ' / ${fmtAmt(limit)}', style: const TextStyle(fontSize: 13, color: Color(0xFF888780))),
                    ])),
                    const SizedBox(width: 6),
                    // #1 edit button
                    GestureDetector(
                      onTap: () => _showEditBudgetDialog(context, p, entry.key, limit),
                      child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF888780)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 8,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), valueColor: AlwaysStoppedAnimation(col)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('${(pct * 100).round()}% used', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                    const Spacer(),
                    Text('${fmtAmt(limit - spent)} left', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                  ]),
                ]),
              ),
            );
          }),
          const SizedBox(height: 20),

          // ── UPI app breakdown ─────────────────────────────
          const SectionHeader(title: 'UPI APP BREAKDOWN'),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: () {
              final apps   = p.appTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              if (apps.isEmpty) {
                // #18 — proper empty state instead of blank card
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No transactions this month', style: TextStyle(color: Color(0xFF888780), fontSize: 13))),
                );
              }
              final maxApp = apps.first.value;
              return Column(children: apps.map((e) {
                final col = AppColors.upiApp[e.key] ?? const Color(0xFF888780);
                return BarRow(label: e.key, value: e.value, maxValue: maxApp, color: col);
              }).toList());
            }(),
          )),
          const SizedBox(height: 20),

          // ── Savings goals ─────────────────────────────────
          const SectionHeader(title: 'SAVINGS GOALS'),
          if (p.goals.isEmpty)
            const EmptyState(message: 'No savings goals yet. Add one below!'),

          // #2 & #3 — Update and delete goals
          ...p.goals.asMap().entries.map((entry) {
            final idx = entry.key;
            final g   = entry.value;
            return Dismissible(
              key: ValueKey('goal_$idx'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16),
                color: AppTheme.danger,
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete savings goal?'),
                    content: Text('Remove "${g.name}" goal?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
                    ],
                  ),
                );
              },
              onDismissed: (_) => p.removeGoal(idx), // #3 — delete goal
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.savings_outlined, size: 18, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmtAmt(g.saved), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success)),
                        Text('of ${fmtAmt(g.target)}', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                      ]),
                      const SizedBox(width: 8),
                      // #2 — add money to goal
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.success),
                        tooltip: 'Add savings',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showUpdateGoalDialog(context, p, idx),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: g.percent, minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.success)),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('${(g.percent * 100).round()}% saved', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                      const Spacer(),
                      Text('${fmtAmt(g.remaining)} to go', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                    ]),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Swipe left on a goal to delete it', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showAddGoalDialog(context, p),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add savings goal'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}
