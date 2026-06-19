import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final p       = context.watch<ExpenseProvider>();
    final cats    = p.categoryTotals;
    final total   = p.monthTotal;
    final topCat  = cats.isNotEmpty ? cats.entries.reduce((a, b) => a.value > b.value ? a : b) : null;
    final foodPct = total > 0 ? ((cats['Food & Dining'] ?? 0) / total * 100).round() : 0;
    final dayTotals = p.weekdayTotals;
    final maxDay    = dayTotals.fold(0.0, (a, b) => a > b ? a : b);
    // #9 fix — use index-aware peakDayIndex from provider, not indexOf which breaks on ties
    final peakIdx = p.peakDayIndex;
    final peakDay = peakIdx >= 0 ? _weekdays[peakIdx] : '—';
    final merchants = p.merchantTotals;
    final maxM    = merchants.isNotEmpty ? merchants.values.reduce((a, b) => a > b ? a : b) : 1.0;
    // #21 — theme-aware chart colors
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final barBase = isDark ? const Color(0xFF2D5580) : const Color(0xFFB5D4F4);
    final gridLine = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1EFE8);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(  // #17
        onRefresh: p.load,
        child: ListView(padding: const EdgeInsets.all(16), children: [

        // ── Smart insight cards ───────────────────────
        const SectionHeader(title: 'SMART INSIGHTS'),
        if (topCat != null) _InsightCard(
          tag: 'Top category',
          tagColor: isDark ? const Color(0xFF162B44) : const Color(0xFFE6F1FB),
          tagTextColor: isDark ? const Color(0xFF8AB9E8) : const Color(0xFF0C447C),
          title: '${topCat.key} is your biggest expense',
          subtitle: 'You spent ${fmtAmt(topCat.value)} (${total > 0 ? (topCat.value / total * 100).round() : 0}% of total) on ${topCat.key} this month.',
          icon: AppIcons.category[topCat.key] ?? Icons.category,
          iconColor: AppColors.category[topCat.key] ?? AppTheme.primary,
        ),
        _InsightCard(
          tag: foodPct > 35 ? 'Food alert' : 'Food healthy',
          tagColor: foodPct > 35
              ? (isDark ? const Color(0xFF4C1D1D) : const Color(0xFFFCEBEB))
              : (isDark ? const Color(0xFF1A330E) : const Color(0xFFEAF3DE)),
          tagTextColor: foodPct > 35
              ? (isDark ? const Color(0xFFFFA5A5) : const Color(0xFF791F1F))
              : (isDark ? const Color(0xFFAFE08D) : const Color(0xFF27500A)),
          title: foodPct > 35 ? 'Food spend is high at $foodPct%' : 'Food spend is healthy at $foodPct%',
          subtitle: foodPct > 35 ? 'Consider cooking at home to reduce dining costs.' : 'Great job keeping food costs under control.',
          icon: Icons.restaurant_outlined,
          iconColor: foodPct > 35 ? AppTheme.danger : AppTheme.success,
        ),
        _InsightCard(
          tag: 'Peak day',
          tagColor: isDark ? const Color(0xFF3B2A0F) : const Color(0xFFFAEEDA),
          tagTextColor: isDark ? const Color(0xFFFCD394) : const Color(0xFF633806),
          title: '$peakDay is your highest spend day',
          subtitle: 'You tend to spend more on ${peakDay}s. Plan ahead to avoid impulse purchases.',
          icon: Icons.calendar_today_outlined, iconColor: AppTheme.warning,
        ),
        _InsightCard(
          tag: 'Tip',
          tagColor: isDark ? const Color(0xFF103328) : const Color(0xFFE1F5EE),
          tagTextColor: isDark ? const Color(0xFF94FCDA) : const Color(0xFF085041),
          title: 'Track your no-spend days',
          subtitle: 'Building a habit of not spending one day a week can save ₹2,000+ monthly.',
          icon: Icons.emoji_events_outlined, iconColor: AppTheme.success,
        ),
        const SizedBox(height: 20),

        // ── Top merchants ─────────────────────────────
        const SectionHeader(title: 'TOP MERCHANTS'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: merchants.entries.map((e) {
                final cat    = p.expenses.where((ex) => ex.name == e.key).map((ex) => ex.category).firstOrNull ?? 'Other';
                final col    = AppColors.category[cat] ?? const Color(0xFF888780);
                final ico    = AppIcons.category[cat]  ?? Icons.more_horiz;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(ico, size: 16, color: col),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: Text(e.key, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / maxM, minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(col),
                      ),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: Text(fmtAmt(e.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: col), textAlign: TextAlign.right)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Weekly pattern ────────────────────────────
        const SectionHeader(title: 'WEEKLY PATTERN'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: SizedBox(
              height: 150,
              child: BarChart(BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    tooltipBorder: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_weekdays[group.x]}\n₹${rod.toY.toStringAsFixed(2)}',
                        TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(7, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: dayTotals[i],
                    // #21 — use theme-aware colors
                    color: i == peakIdx ? AppTheme.primary : barBase,
                    width: 22, borderRadius: BorderRadius.circular(4),
                  )],
                )),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 24,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_weekdays[v.toInt()], style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  )),
                ),
                gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: gridLine)),
                borderData: FlBorderData(show: false),
                maxY: maxDay * 1.25,
              )),
            ),
          ),
        ),
        const SizedBox(height: 30),
        ]),  // end ListView
      ),     // end RefreshIndicator
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String tag, title, subtitle;
  final Color tagColor, tagTextColor;
  final IconData iconData;
  final Color? iconColor;

  const _InsightCard({
    required this.tag, required this.title, required this.subtitle,
    required this.tagColor, required this.tagTextColor,
    IconData? icon, this.iconColor,
  }) : iconData = icon ?? Icons.lightbulb_outline;

  @override
  Widget build(BuildContext context) {
    final effIconColor = iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(iconData, size: 18, color: effIconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(20)),
              child: Text(tag, style: TextStyle(fontSize: 10, color: tagTextColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 5),
            Text(title,    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          ])),
        ]),
      ),
    );
  }
}
