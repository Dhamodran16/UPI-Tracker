class Expense {
  final String? id;
  final String name;
  final double amount;
  final String category;
  final String upiApp;
  final String? upiRef;
  final String? note;
  final DateTime date;
  final String type; // 'debit', 'credit', 'autopay_created', 'autopay_cancelled'

  Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.upiApp,
    this.upiRef,
    this.note,
    required this.date,
    this.type = 'debit',
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id:       j['_id'] as String?,
    name:     j['payee'] as String? ?? '',
    amount:   (j['amount'] as num).toDouble(),
    category: j['category'] as String? ?? 'Other',
    upiApp:   j['upiApp']  as String? ?? 'GPay',
    upiRef:   j['upiRef']  as String?,
    note:     j['note']    as String?,
    date:     DateTime.parse(j['date'] as String),
    type:     j['type']    as String? ?? 'debit',
  );

  Map<String, dynamic> toJson() => {
    'payee':    name,
    'amount':   amount,
    'category': category,
    'upiApp':   upiApp,
    if (upiRef != null && upiRef!.isNotEmpty) 'upiRef': upiRef,
    if (note   != null && note!.isNotEmpty)   'note':   note,
    'date':     date.toIso8601String(),
    'type':     type,
  };

  Expense copyWith({String? id, String? name, double? amount, String? category,
      String? upiApp, String? upiRef, String? note, DateTime? date, String? type}) =>
    Expense(
      id:       id       ?? this.id,
      name:     name     ?? this.name,
      amount:   amount   ?? this.amount,
      category: category ?? this.category,
      upiApp:   upiApp   ?? this.upiApp,
      upiRef:   upiRef   ?? this.upiRef,
      note:     note     ?? this.note,
      date:     date     ?? this.date,
      type:     type     ?? this.type,
    );
}

class MonthlySummary {
  final int month;
  final int year;
  final double total;
  final int count;
  final List<CategoryTotal> categoryBreakdown;
  final List<DailyTotal>    dailyTrend;

  MonthlySummary({
    required this.month, required this.year,
    required this.total, required this.count,
    required this.categoryBreakdown, required this.dailyTrend,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> j) => MonthlySummary(
    month: j['month'] as int,
    year:  j['year']  as int,
    total: (j['total'] as num).toDouble(),
    count: j['count'] as int,
    categoryBreakdown: (j['categoryBreakdown'] as List)
        .map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>)).toList(),
    dailyTrend: (j['dailyTrend'] as List)
        .map((e) => DailyTotal.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class CategoryTotal {
  final String category;
  final double total;
  final int    count;
  CategoryTotal({required this.category, required this.total, required this.count});
  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
    category: j['_id']   as String,
    total:    (j['total'] as num).toDouble(),
    count:    j['count'] as int,
  );
}

class DailyTotal {
  final String date;
  final double total;
  DailyTotal({required this.date, required this.total});
  factory DailyTotal.fromJson(Map<String, dynamic> j) => DailyTotal(
    date:  j['_id']   as String,
    total: (j['total'] as num).toDouble(),
  );
}

class SavingsGoal {
  final String name;
  final double target;
  final double saved;
  SavingsGoal({required this.name, required this.target, required this.saved});
  double get percent   => (saved / target).clamp(0, 1);
  double get remaining => target - saved;

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
    name:   j['name']   as String,
    target: (j['target'] as num).toDouble(),
    saved:  (j['saved']  as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'name': name, 'target': target, 'saved': saved};

  SavingsGoal copyWith({String? name, double? target, double? saved}) => SavingsGoal(
    name:   name   ?? this.name,
    target: target ?? this.target,
    saved:  saved  ?? this.saved,
  );
}
