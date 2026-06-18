import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // #11 fix — Form with GlobalKey for inline validation
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _amount  = TextEditingController();
  final _ref     = TextEditingController();
  final _note    = TextEditingController();
  String   _cat  = 'Food & Dining';
  String   _app  = 'GPay';
  DateTime _date = DateTime.now();
  bool _saving   = false;
  late Future<bool> _permFuture;

  @override
  void initState() {
    super.initState();
    _permFuture = NotificationService.isPermissionGranted();
  }

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
    final e = Expense(
      name:     _name.text.trim(),
      amount:   double.parse(_amount.text),
      category: _cat,
      upiApp:   _app,
      upiRef:   _ref.text.trim().isEmpty ? null : _ref.text.trim(),
      note:     _note.text.trim().isEmpty ? null : _note.text.trim(),
      date:     _date,
    );
    final err = await context.read<ExpenseProvider>().addExpense(e);
    if (mounted) {
      setState(() => _saving = false);
      if (err == null) {
        _name.clear(); _amount.clear(); _ref.clear(); _note.clear();
        setState(() { _cat = 'Food & Dining'; _app = 'GPay'; _date = DateTime.now(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved ✔')));
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
      appBar: AppBar(title: const Text('Add expense')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // Notification permission banner
          FutureBuilder<bool>(
            future: _permFuture,
            builder: (_, snap) {
              if (snap.data == true) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBA7517).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.notifications_outlined, color: Color(0xFFBA7517), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Enable notification access for auto-tracking', style: TextStyle(fontSize: 13, color: Color(0xFF633806)))),
                  TextButton(onPressed: NotificationService.openNotificationSettings, child: const Text('Enable', style: TextStyle(fontSize: 12))),
                ]),
              );
            },
          ),

          _label('Payee / merchant'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Swiggy, Petrol bunk…'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Payee name is required' : null,
          ),
          const SizedBox(height: 14),

          _label('Amount (₹)'),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
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
                    Text('${_date.day}/${_date.month}/${_date.year}', style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('UPI app'),
              DropdownButtonFormField<String>(
                value: _app, decoration: const InputDecoration(),
                items: kUpiApps.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _app = v!),
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
          TextField(controller: _ref, decoration: const InputDecoration(hintText: 'e.g. 406123456789')),
          const SizedBox(height: 14),

          _label('Note (optional)'),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'Add a note…'), maxLines: 2),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Save expense'),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF888780), fontWeight: FontWeight.w500)),
  );
}
