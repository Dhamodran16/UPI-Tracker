import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;
  const EditExpenseScreen({super.key, required this.expense});
  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name   = TextEditingController(text: widget.expense.name);
  late final _amount = TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
  late final _ref    = TextEditingController(text: widget.expense.upiRef ?? '');
  late final _note   = TextEditingController(text: widget.expense.note   ?? '');
  late String   _cat  = widget.expense.category;
  late String   _app  = widget.expense.upiApp;
  late DateTime _date = widget.expense.date;
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); _amount.dispose(); _ref.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date,
        firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'payee':    _name.text.trim(),
      'amount':   double.parse(_amount.text),
      'category': _cat,
      'upiApp':   _app,
      'date':     _date.toIso8601String(),
      'upiRef':   _ref.text.trim().isEmpty ? null : _ref.text.trim(),
      'note':     _note.text.trim().isEmpty ? null : _note.text.trim(),
    };

    final err = await context.read<ExpenseProvider>().updateExpense(widget.expense.id!, data);
    if (mounted) {
      setState(() => _saving = false);
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated ✔')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit expense'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _label('Payee / merchant'),
          TextFormField(
            controller: _name,
            style: const TextStyle(fontSize: 16),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Swiggy'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Payee is required' : null,
          ),
          const SizedBox(height: 14),

          _label('Amount (₹)'),
          TextFormField(
            controller: _amount,
            style: const TextStyle(fontSize: 16),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00', prefixText: '₹ '),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Date'),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF888780)),
                    const SizedBox(width: 8),
                    Text('${_date.day}/${_date.month}/${_date.year}', style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('UPI app'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _app,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF888780)),
                    items: kUpiApps.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a, style: const TextStyle(fontSize: 16)),
                    )).toList(),
                    onChanged: (v) => setState(() => _app = v!),
                  ),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          _label('Category'),
          Wrap(spacing: 8, runSpacing: 8, children: kCategories.map((cat) {
            final active = _cat == cat;
            final col    = AppColors.category[cat] ?? const Color(0xFF888780);
            final ico    = AppIcons.category[cat]  ?? Icons.more_horiz;
            return GestureDetector(
              onTap: () => setState(() => _cat = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:  active ? col.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                  border: Border.all(color: active ? col : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ico, size: 16, color: active ? col : const Color(0xFF888780)),
                  const SizedBox(width: 6),
                  Text(cat, style: TextStyle(fontSize: 12, color: active ? col : const Color(0xFF888780), fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),

          _label('UPI ref (optional)'),
          TextField(
            controller: _ref,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(hintText: 'e.g. 406123456789'),
          ),
          const SizedBox(height: 14),

          _label('Note (optional)'),
          TextField(
            controller: _note,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(hintText: 'Add a note…'),
            maxLines: 2,
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
  );
}
