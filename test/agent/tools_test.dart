// Host-side tests for the Stage-1 tools. These exercise the real tool funcs
// (DB read, pure compute, in-memory calendar) without Firebase — the LLM/agent
// loop itself is verified on the emulator.

import 'dart:convert';

import 'package:finance_ai_assistant/agent/agent_service.dart';
import 'package:finance_ai_assistant/agent/tools/query_transactions.dart';
import 'package:finance_ai_assistant/agent/tools/set_budget_reminder.dart';
import 'package:finance_ai_assistant/agent/tools/summarize_spending.dart';
import 'package:finance_ai_assistant/agent/tools/update_budget_reminder.dart';
import 'package:finance_ai_assistant/data/calendar_service.dart';
import 'package:finance_ai_assistant/data/transaction_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langchain/langchain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  TransactionRepo newRepo() => TransactionRepo(
        clock: () => DateTime(2026, 6, 5),
        dbPath: inMemoryDatabasePath,
      );

  // fromFunction tools are statically typed as the raw `Tool` (Output=Object),
  // so cast the String result back for decoding.
  Future<String> run(Tool tool, Map<String, dynamic> args) async =>
      await tool.invoke(args) as String;

  Map<String, dynamic> decode(String s) =>
      jsonDecode(s) as Map<String, dynamic>;

  group('query_transactions tool', () {
    test('last_month returns rows summing to 47,200', () async {
      final repo = newRepo();
      final tool = buildQueryTransactionsTool(repo);
      final rows = (jsonDecode(await run(tool, {'period': 'last_month'})) as List)
          .cast<Map<String, dynamic>>();
      final total = rows.fold<int>(0, (a, r) => a + (r['amount'] as int));
      expect(total, 47200);
      await repo.close();
    });

    test('category filter (entertainment) sums to 6,800', () async {
      final repo = newRepo();
      final tool = buildQueryTransactionsTool(repo);
      final rows = (jsonDecode(await run(
                  tool, {'period': 'last_month', 'category': 'entertainment'}))
              as List)
          .cast<Map<String, dynamic>>();
      final total = rows.fold<int>(0, (a, r) => a + (r['amount'] as int));
      expect(total, 6800);
      await repo.close();
    });
  });

  group('summarize_spending tool', () {
    test('groups by category and picks food as top', () async {
      final tool = buildSummarizeSpendingTool();
      final txns = jsonEncode([
        {'amount': 14800, 'category': 'food', 'date': '2026-05-03', 'merchant': 'Swiggy'},
        {'amount': 6800, 'category': 'entertainment', 'date': '2026-05-04', 'merchant': 'Netflix'},
        {'amount': 3100, 'category': 'transport', 'date': '2026-05-01', 'merchant': 'Uber'},
      ]);
      final res = decode(await run(tool, {'transactions_json': txns}));
      expect(res['total'], 24700);
      expect(res['topCategory'], 'food');
      expect((res['byCategory'] as Map)['food'], 14800);
    });
  });

  group('reminder tools', () {
    test('set then update changes recurrence on the same reminder', () async {
      final cal = InMemoryCalendarService();
      final setTool = buildSetBudgetReminderTool(cal);
      final updateTool = buildUpdateBudgetReminderTool(cal);

      final created = decode(await run(setTool, {
        'title': 'Review food spending',
        'category': 'food',
        'recurrence': 'monthly',
      }));
      expect(created['recurrence'], 'monthly');
      expect(created['status'], 'created');

      final updated = decode(await run(updateTool, {
        'category': 'food',
        'recurrence': 'weekly',
      }));
      expect(updated['recurrence'], 'weekly');
      expect(updated['id'], created['id']); // same reminder, in place
      expect(cal.reminderFor('food')?['recurrence'], 'weekly');
    });
  });

  group('tool set (sandbox boundary)', () {
    test('is exactly the four expected tools — no delete/wipe tool', () {
      final names = buildAriaTools(
        repo: newRepo(),
        calendar: InMemoryCalendarService(),
      ).map((t) => t.name).toSet();

      expect(names, {
        'query_transactions',
        'summarize_spending',
        'set_budget_reminder',
        'update_budget_reminder',
      });
      expect(names.any((n) => n.contains('delete') || n.contains('wipe')),
          isFalse);
    });
  });
}
