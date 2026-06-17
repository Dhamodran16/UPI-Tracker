import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showLine = false;

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ApiService().logout();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<ExpenseProvider>();
    final now  = DateTime.now();
    final days = DateUtils.getDaysInMonth(p.selectedYear, p.selectedMonth);

    // Daily data
    final dailyMap = <int, double>{};
    for (final e in p.monthExpenses) dailyMap[e.date.day] = (dailyMap[e.date.day] ?? 0) + e.amount;
    final maxDaily = dailyMap.values.fold(0.0, (a, b) => a > b ? a : b);

    final cats    = p.categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat  = cats.isEmpty ? 1.0 : cats.first.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          // Month picker
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: '${p.selectedMonth}/${p.selectedYear}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
                items: List.generate(12, (i) {
                  final d = DateTime(now.year, now.month - i);
                  return DropdownMenuItem(
                    value: '${d.month}/${d.year}',
                    child: Text(DateFormat('MMM yyyy').format(d)),
                  );
                }),
                onChanged: (v) {
                  final parts = v!.split('/');
                  p.setMonth(int.parse(parts[0]), int.parse(parts[1]));
                },
              ),
            ),
          ),
          // Logout (#4)
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),

      // #15 — Show error state when loading fails
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.error != null && p.monthExpenses.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF888780)),
                  const SizedBox(height: 12),
                  Text(p.error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888780))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: p.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ]))
              : RefreshIndicator(
                  onRefresh: p.load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [

                    // ── Metric cards ──────────────────────────────────
                    GridView.count(
                      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
                      children: [
                        MetricCard(label: 'Total spent', value: fmtAmt(p.monthTotal), sub: '${p.monthExpenses.length} transactions', valueColor: AppTheme.danger),
                        MetricCard(label: 'Daily avg', value: fmtAmt(days > 0 ? p.monthTotal / days : 0), sub: 'Today: ${fmtAmt(p.todayTotal)}', valueColor: AppTheme.warning),
                        MetricCard(label: 'Largest txn', value: fmtAmt(p.maxExpense?.amount ?? 0), sub: p.maxExpense?.name ?? '—'),
                        MetricCard(label: 'UPI apps', value: p.uniqueApps.toString(), sub: p.topApp),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Category breakdown ────────────────────────────
                    if (cats.isNotEmpty) ...[
                      const SectionHeader(title: 'SPENDING BY CATEGORY'),
                      ...cats.map((e) => BarRow(
                        label: e.key, value: e.value, maxValue: maxCat,
                        color: AppColors.category[e.key] ?? const Color(0xFF888780),
                      )),
                      const SizedBox(height: 20),
                    ],

                    // ── Daily trend chart ──────────────────────────────
                    SectionHeader(
                      title: 'DAILY TREND',
                      trailing: Row(children: [
                        _chartToggle('Bar', !_showLine, () => setState(() => _showLine = false)),
                        const SizedBox(width: 6),
                        _chartToggle('Line', _showLine,  () => setState(() => _showLine = true)),
                      ]),
                    ),
                    SizedBox(
                      height: 160,
                      child: _showLine
                          ? LineChart(LineChartData(
                              lineBarsData: [LineChartBarData(
                                spots: List.generate(days, (i) => FlSpot((i+1).toDouble(), dailyMap[i+1] ?? 0)),
                                isCurved: true, color: AppTheme.primary, barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.08)),
                              )],
                              titlesData: _chartTitles(days),
                              gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1EFE8))),
                              borderData: FlBorderData(show: false),
                            ))
                          : BarChart(BarChartData(
                              barGroups: List.generate(days, (i) => BarChartGroupData(
                                x: i + 1,
                                barRods: [BarChartRodData(toY: dailyMap[i+1] ?? 0, color: AppTheme.primary.withValues(alpha: 0.5), width: 6, borderRadius: BorderRadius.circular(3))],
                              )),
                              titlesData: _chartTitles(days),
                              gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1EFE8))),
                              borderData: FlBorderData(show: false),
                              maxY: maxDaily * 1.2,
                            )),
                    ),
                    const SizedBox(height: 20),

                    // ── Recent transactions ────────────────────────────
                    SectionHeader(
                      title: 'RECENT',
                      trailing: TextButton(
                        // #5 fix — navigate via provider.setTab()
                        onPressed: () => context.read<ExpenseProvider>().setTab(1),
                        child: const Text('See all', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    if (p.monthExpenses.isEmpty)
                      const EmptyState(message: 'No transactions this month')
                    else
                      ...p.monthExpenses.take(5).map((e) => Column(children: [
                        TxnTile(
                          expense: e,
                          onDelete: e.id != null ? () async {
                            final err = await p.deleteExpense(e.id!);
                            if (err != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
                              );
                            }
                          } : null,
                        ),
                        const Divider(height: 0.5),
                      ])),
                  ]),
                ),
    );
  }

  Widget _chartToggle(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : AppTheme.primary)),
    ),
  );

  FlTitlesData _chartTitles(int days) => FlTitlesData(
    leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
      getTitlesWidget: (v, _) => v % 5 == 0 ? Text('${v.toInt()}', style: const TextStyle(fontSize: 10)) : const SizedBox(),
    )),
  );
}
