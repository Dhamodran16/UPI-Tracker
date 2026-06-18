import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showLine = false;

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<ExpenseProvider>();
    final now  = DateTime.now();
    final days = DateUtils.getDaysInMonth(p.selectedYear, p.selectedMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Daily data
    final dailyMap = <int, double>{};
    for (final e in p.monthExpenses) dailyMap[e.date.day] = (dailyMap[e.date.day] ?? 0) + e.amount;
    final maxDaily = dailyMap.values.fold(0.0, (a, b) => a > b ? a : b);

    final cats    = p.categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat  = cats.isEmpty ? 1.0 : cats.first.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          // Month picker
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: '${p.selectedMonth}/${p.selectedYear}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                dropdownColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF1E1E1E) 
                    : Colors.white,
                items: (() {
                  final list = List<Map<String, int>>.from(p.trackedMonths);
                  final hasSelected = list.any((m) => m['month'] == p.selectedMonth && m['year'] == p.selectedYear);
                  if (!hasSelected) {
                    list.add({'month': p.selectedMonth, 'year': p.selectedYear});
                    list.sort((a, b) {
                      if (a['year'] != b['year']) return b['year']!.compareTo(a['year']!);
                      return b['month']!.compareTo(a['month']!);
                    });
                  }
                  return list.map((m) {
                    final d = DateTime(m['year']!, m['month']!);
                    return DropdownMenuItem(
                      value: '${d.month}/${d.year}',
                      child: Text(DateFormat('MMM yyyy').format(d)),
                    );
                  }).toList();
                })(),
                onChanged: (v) {
                  final parts = v!.split('/');
                  p.setMonth(int.parse(parts[0]), int.parse(parts[1]));
                },
              ),
            ),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (spot) => isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                  tooltipBorder: BorderSide(
                                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      return LineTooltipItem(
                                        'Day ${spot.x.toInt()}\n₹${spot.y.toStringAsFixed(2)}',
                                        TextStyle(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
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
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (group) => isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                  tooltipBorder: BorderSide(
                                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      'Day ${group.x}\n₹${rod.toY.toStringAsFixed(2)}',
                                      TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
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
