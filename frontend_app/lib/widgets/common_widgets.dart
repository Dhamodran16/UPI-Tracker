import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../utils/app_theme.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String fmtAmt(double v) => _fmt.format(v.roundToDouble());

// ── Metric card ──────────────────────────────────────────────────────────────
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color?  valueColor;
  const MetricCard({super.key, required this.label, required this.value, this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: valueColor)),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub!, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ]),
  );
}

// ── Category icon circle ─────────────────────────────────────────────────────
class CatIcon extends StatelessWidget {
  final String category;
  final double size;
  const CatIcon({super.key, required this.category, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final col = AppColors.category[category] ?? const Color(0xFF888780);
    final bg  = col.withValues(alpha: isDark ? 0.16 : 0.10);
    final ico = AppIcons.category[category] ?? Icons.more_horiz;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(ico, color: col, size: size * 0.46),
    );
  }
}

// ── Transaction list tile ────────────────────────────────────────────────────
class TxnTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const TxnTile({super.key, required this.expense, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(expense.id ?? expense.name + expense.date.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFFCEBEB),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Color(0xFFA32D2D)),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: Text('Remove ${expense.name} ${fmtAmt(expense.amount)}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete', style: TextStyle(color: Color(0xFFA32D2D)))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(children: [
            CatIcon(category: expense.category),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(expense.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('d MMM, h:mm a').format(expense.date)}  ·  ${expense.upiApp}${expense.note != null && expense.note!.isNotEmpty ? "  ·  ${expense.note}" : ""}',
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                expense.type == 'credit'
                    ? '+${fmtAmt(expense.amount)}'
                    : expense.type == 'autopay_created'
                        ? 'Limit ${fmtAmt(expense.amount)}'
                        : expense.type == 'autopay_cancelled'
                            ? 'Cancelled'
                            : '-${fmtAmt(expense.amount)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: expense.type == 'credit'
                      ? const Color(0xFF2E7D32)
                      : expense.type == 'autopay_created'
                          ? const Color(0xFF1565C0)
                          : expense.type == 'autopay_cancelled'
                              ? const Color(0xFF757575)
                              : const Color(0xFFA32D2D),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (expense.type == 'autopay_created' || expense.type == 'autopay_cancelled'
                          ? const Color(0xFF757575)
                          : (AppColors.category[expense.category] ?? const Color(0xFF888780)))
                      .withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expense.type == 'autopay_created'
                      ? 'Autopay Setup'
                      : expense.type == 'autopay_cancelled'
                          ? 'Autopay Revoked'
                          : expense.category,
                  style: TextStyle(
                    fontSize: 14,
                    color: expense.type == 'autopay_created' || expense.type == 'autopay_cancelled'
                        ? const Color(0xFF757575)
                        : AppColors.category[expense.category] ?? const Color(0xFF888780),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Horizontal bar ───────────────────────────────────────────────────────────
class BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color  color;
  final String? valueLabel;
  const BarRow({super.key, required this.label, required this.value, required this.maxValue, required this.color, this.valueLabel});

  @override
  Widget build(BuildContext context) {
    final pct = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(valueLabel ?? fmtAmt(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
  );
}

// ── Empty state ──────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: Colors.grey.shade400, fontSize: 18), textAlign: TextAlign.center),
      ]),
    ),
  );
}
