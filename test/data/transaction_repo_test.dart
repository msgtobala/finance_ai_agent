// Host-side tests for the data layer. sqflite_common_ffi runs a real SQLite on
// the dev machine, so these run under `flutter test` without an emulator.

import 'package:finance_ai_assistant/data/seed_data.dart';
import 'package:finance_ai_assistant/data/transaction_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Fixed clock → previous calendar month is deterministically May 2026.
  TransactionRepo newRepo() => TransactionRepo(
        clock: () => DateTime(2026, 6, 5),
        dbPath: inMemoryDatabasePath,
      );

  Future<Map<String, int>> lastMonthTotals(TransactionRepo repo) async {
    final rows = await repo.query(period: 'last_month');
    final totals = <String, int>{};
    for (final r in rows) {
      final c = r['category'] as String;
      totals[c] = (totals[c] ?? 0) + (r['amount'] as int);
    }
    return totals;
  }

  test('seeds last month to the fixed §3.5 totals with food dominant', () async {
    final repo = newRepo();
    final totals = await lastMonthTotals(repo);

    expect(totals, kCategoryTotals);
    expect(totals.values.fold<int>(0, (a, b) => a + b), kGrandTotal);

    final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    expect(top, 'food');

    await repo.close();
  });

  test('entertainment query sums to 6800 (Beat 3)', () async {
    final repo = newRepo();
    final rows =
        await repo.query(period: 'last_month', category: 'entertainment');
    final sum = rows.fold<int>(0, (a, r) => a + (r['amount'] as int));
    expect(sum, 6800);
    await repo.close();
  });

  test('seedIfEmpty is idempotent (no duplicate rows)', () async {
    final repo = newRepo();
    await repo.seedIfEmpty();
    await repo.seedIfEmpty();
    final totals = await lastMonthTotals(repo);
    expect(totals, kCategoryTotals);
    expect(totals.values.fold<int>(0, (a, b) => a + b), kGrandTotal);
    await repo.close();
  });

  test('resetDemoData reseeds to identical totals', () async {
    final repo = newRepo();
    final before = await lastMonthTotals(repo);
    await repo.resetDemoData();
    final after = await lastMonthTotals(repo);
    expect(after, before);
    expect(after.values.fold<int>(0, (a, b) => a + b), kGrandTotal);
    await repo.close();
  });

  test('all seeded dates fall in the previous calendar month (May 2026)',
      () async {
    final repo = newRepo();
    final rows = await repo.query(period: 'last_month');
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect((r['date'] as String).startsWith('2026-05'), isTrue,
          reason: 'date ${r['date']} not in May 2026');
    }
    await repo.close();
  });

  test('this_month / this_week return empty (seed only populates last_month)',
      () async {
    final repo = newRepo();
    expect(await repo.query(period: 'this_month'), isEmpty);
    expect(await repo.query(period: 'this_week'), isEmpty);
    await repo.close();
  });
}
