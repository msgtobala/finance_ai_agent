import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

/// Read surface over the seeded local transaction database (sqflite).
///
/// This is the SANDBOX BOUNDARY for the agent: the only method ever wrapped as a
/// LangChain `Tool` (step 4) is [query] — it is READ-ONLY. [seedIfEmpty] and
/// [resetDemoData] are app/dev-only and are deliberately NEVER exposed to the
/// model. There is no delete/update tool by design (CLAUDE.md / STORYLINE Beat
/// 4): the absence of such a capability is the safety mechanism.
class TransactionRepo {
  /// [clock] is injectable so the relative "last month" logic is deterministic
  /// and unit-testable. [dbPath] overrides the on-device path (tests pass
  /// `inMemoryDatabasePath`).
  TransactionRepo({DateTime Function()? clock, String? dbPath})
      : _clock = clock ?? DateTime.now,
        _dbPathOverride = dbPath;

  final DateTime Function() _clock;
  final String? _dbPathOverride;

  static final Logger _log = Logger('aria.data.transactionRepo');
  static const String _table = 'transactions';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database async =>
      _db ?? (_opening ??= _open());

  Future<Database> _open() async {
    final path =
        _dbPathOverride ?? p.join(await getDatabasesPath(), 'aria_demo.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            merchant TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        await _insertSeed(db);
      },
    );
    _db = db;
    // Defensive: seed if the table somehow exists but is empty.
    await _seedIfEmpty(db);
    return db;
  }

  /// Idempotent: inserts the fixed [kSeedTransactions] only when the table is
  /// empty. Safe to call repeatedly.
  Future<void> seedIfEmpty() async => _seedIfEmpty(await _database);

  /// Wipe + reseed to the identical §3.5 totals. Call before each rehearsal so
  /// every run starts from the same state (ARCHITECTURE §7).
  Future<void> resetDemoData() async {
    final db = await _database;
    await db.delete(_table);
    await _insertSeed(db);
  }

  /// READ-ONLY query used by the Stage-1 `query_transactions` tool. Returns a
  /// JSON-encodable list of `{amount, category, date, merchant}` for the given
  /// [period] and optional [category], ordered by date. Never throws — returns
  /// an empty list and logs on failure so the demo can't hard-crash on stage.
  Future<List<Map<String, Object?>>> query({
    required String period,
    String? category,
  }) async {
    try {
      final db = await _database;
      final (:start, :end) = _rangeForPeriod(period, _clock());
      final where = StringBuffer('date >= ? AND date <= ?');
      final args = <Object?>[_isoDate(start), _isoDate(end)];
      if (category != null) {
        where.write(' AND category = ?');
        args.add(category);
      }
      return await db.query(
        _table,
        columns: const ['amount', 'category', 'date', 'merchant'],
        where: where.toString(),
        whereArgs: args,
        orderBy: 'date ASC',
      );
    } catch (e, st) {
      _log.warning('query failed (period=$period, category=$category)', e, st);
      return const [];
    }
  }

  /// Close the underlying database (used by the provider's onDispose and tests).
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }

  // --- internals -----------------------------------------------------------

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_table'),
        ) ??
        0;
    if (count == 0) await _insertSeed(db);
  }

  Future<void> _insertSeed(Database db) async {
    final prevMonth = _previousMonthFirstDay(_clock());
    final batch = db.batch();
    for (final t in kSeedTransactions) {
      final date = DateTime(prevMonth.year, prevMonth.month, t.dayOfMonth);
      batch.insert(_table, {
        'amount': t.amount,
        'category': t.category,
        'merchant': t.merchant,
        'date': _isoDate(date),
      });
    }
    await batch.commit(noResult: true);
  }

  /// First day of the calendar month before [now]. Handles Jan→Dec rollover.
  static DateTime _previousMonthFirstDay(DateTime now) {
    final firstOfThis = DateTime(now.year, now.month, 1);
    final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
    return DateTime(lastOfPrev.year, lastOfPrev.month, 1);
  }

  /// Inclusive `[start, end]` date range for a period string, relative to [now].
  /// Only `last_month` carries seeded data (the beats use it); `this_month` /
  /// `this_week` are supported for completeness and return empty by design.
  static ({DateTime start, DateTime end}) _rangeForPeriod(
      String period, DateTime now) {
    switch (period) {
      case 'last_month':
        final start = _previousMonthFirstDay(now);
        final end =
            DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        return (start: start, end: end);
      case 'this_month':
        return (start: DateTime(now.year, now.month, 1), end: now);
      case 'this_week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (start: DateTime(monday.year, monday.month, monday.day), end: now);
      default:
        // Unknown period → empty range (start after end).
        return (start: now, end: now.subtract(const Duration(days: 1)));
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
