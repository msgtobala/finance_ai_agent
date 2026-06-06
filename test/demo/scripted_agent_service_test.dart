// Host tests for ScriptedAgentService. The scripted path needs NO Firebase and NO
// LLM — it runs the real tools (ffi DB + in-memory calendar) and assembles the
// AgentOutcome from fixtures. Proves: scripted kind/trace are replayed, tools
// REALLY run (real effects + calendar writes), and off-script input degrades to
// the injected live runner.

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/agent/agent_service.dart';
import 'package:finance_ai_assistant/agent/scripted_agent_service.dart';
import 'package:finance_ai_assistant/data/calendar_service.dart';
import 'package:finance_ai_assistant/data/transaction_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A live stand-in that records delegation instead of calling Firebase.
class _FakeLive implements AgentRunner {
  String? lastInput;
  int resetCalls = 0;

  @override
  Future<AgentOutcome> runTurn(String input) async {
    lastInput = input;
    return AgentOutcome(
      userText: input,
      answerText: 'live-fallback',
      steps: const [],
      effects: const [],
      kind: OutcomeKind.capabilityInfo,
    );
  }

  @override
  Future<void> resetMemory() async => resetCalls++;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  TransactionRepo newRepo() => TransactionRepo(
        clock: () => DateTime(2026, 6, 5),
        dbPath: inMemoryDatabasePath,
      );

  ({ScriptedAgentService scripted, _FakeLive live, InMemoryCalendarService cal})
      build() {
    final live = _FakeLive();
    final cal = InMemoryCalendarService();
    final scripted = ScriptedAgentService(
      live: live,
      repo: newRepo(),
      calendar: cal,
    );
    return (scripted: scripted, live: live, cal: cal);
  }

  test('Beat 1 → spendingSummary, real summarize effect (47,200), 🧠 trace', () async {
    final h = build();
    final outcome =
        await h.scripted.runTurn('Hey Aria, how much did I spend last month?');

    expect(outcome.kind, OutcomeKind.spendingSummary);
    // Tools really ran: a real summarize_spending result is present.
    final summarize = outcome.effects.firstWhere((e) => e.tool == 'summarize_spending');
    final data = summarize.data as Map;
    expect(data['total'], 47200);
    expect(data['topCategory'], 'food');
    // The scripted trace carries thinking lines live mode can't produce.
    expect(outcome.steps.any((s) => s.kind == TraceStepKind.thinking), isTrue);
    expect(h.live.lastInput, isNull); // did not fall back
  });

  test('Beat 4 → capabilityInfo with NO effects (structural refusal)', () async {
    final h = build();
    final outcome = await h.scripted.runTurn('Delete all my transactions.');
    expect(outcome.kind, OutcomeKind.capabilityInfo);
    expect(outcome.effects, isEmpty);
    expect(h.live.lastInput, isNull);
  });

  test('Beat 2·Confirm → reminderUpdated and the calendar really got the write',
      () async {
    final h = build();
    final outcome = await h.scripted.runTurn(
      'Yes, please go ahead and set a monthly reminder titled "Review food '
      'spending" to review my food spending.',
    );
    expect(outcome.kind, OutcomeKind.reminderUpdated);
    // Real side effect: the in-memory calendar now holds the food reminder.
    expect(h.cal.reminderFor('food'), isNotNull);
    expect(h.cal.reminderFor('food')?['recurrence'], 'monthly');
  });

  test('Beat 5·SetAll → three reminder effects, three real writes', () async {
    final h = build();
    final outcome = await h.scripted.runTurn(
      'Yes, please set monthly reminders to review my food, shopping and '
      'entertainment spending.',
    );
    expect(outcome.kind, OutcomeKind.reminderUpdated);
    final reminderEffects =
        outcome.effects.where((e) => e.tool == 'set_budget_reminder').toList();
    expect(reminderEffects, hasLength(3));
    expect(h.cal.reminderFor('food'), isNotNull);
    expect(h.cal.reminderFor('shopping'), isNotNull);
    expect(h.cal.reminderFor('entertainment'), isNotNull);
  });

  test('off-script input degrades to the live runner', () async {
    final h = build();
    final outcome = await h.scripted.runTurn('What is the capital of France?');
    expect(h.live.lastInput, 'What is the capital of France?');
    expect(outcome.answerText, 'live-fallback');
  });

  test('resetMemory delegates to the live runner', () async {
    final h = build();
    await h.scripted.resetMemory();
    expect(h.live.resetCalls, 1);
  });
}
