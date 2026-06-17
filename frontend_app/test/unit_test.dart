import 'package:flutter_test/flutter_test.dart';
import 'package:upi_tracker/models/expense.dart';

void main() {
  group('Expense Model Tests', () {
    test('toJson and fromJson matching serialization', () {
      final date = DateTime(2026, 6, 17, 12, 0);
      final e = Expense(
        id: '123',
        name: 'Swiggy',
        amount: 250.0,
        category: 'Food & Dining',
        upiApp: 'GPay',
        upiRef: 'TXN12345',
        note: 'lunch',
        date: date,
      );

      final json = e.toJson();
      expect(json['payee'], 'Swiggy');
      expect(json['amount'], 250.0);
      expect(json['category'], 'Food & Dining');
      expect(json['upiApp'], 'GPay');
      expect(json['upiRef'], 'TXN12345');
      expect(json['note'], 'lunch');
      expect(json['date'], date.toIso8601String());

      // Simulate API response structure
      final apiJson = Map<String, dynamic>.from(json)..['_id'] = '123';
      final parsed = Expense.fromJson(apiJson);
      expect(parsed.id, '123');
      expect(parsed.name, 'Swiggy');
      expect(parsed.amount, 250.0);
      expect(parsed.category, 'Food & Dining');
      expect(parsed.upiApp, 'GPay');
      expect(parsed.upiRef, 'TXN12345');
      expect(parsed.note, 'lunch');
      expect(parsed.date, date);
    });

    test('copyWith behaves correctly', () {
      final date = DateTime(2026, 6, 17);
      final e = Expense(name: 'Ola', amount: 150.0, category: 'Transport', upiApp: 'PhonePe', date: date);
      final copy = e.copyWith(amount: 180.0, note: 'rush hour');
      expect(copy.name, 'Ola');
      expect(copy.amount, 180.0);
      expect(copy.note, 'rush hour');
    });
  });

  group('SavingsGoal Model Tests', () {
    test('percent and remaining getters', () {
      final g = SavingsGoal(name: 'Laptop', target: 50000.0, saved: 20000.0);
      expect(g.percent, 0.4);
      expect(g.remaining, 30000.0);
    });

    test('toJson and fromJson matching serialization', () {
      final g = SavingsGoal(name: 'Trip', target: 15000.0, saved: 15000.0);
      final json = g.toJson();
      final parsed = SavingsGoal.fromJson(json);
      expect(parsed.name, 'Trip');
      expect(parsed.target, 15000.0);
      expect(parsed.saved, 15000.0);
      expect(parsed.percent, 1.0);
    });
  });
}
