// Host-side tests for the Stage-1 → Stage-2 seam. Pure Dart: no Firebase, no
// model, no genui — `deriveOutcomeKind` / `buildAgentOutcome` are deterministic
// transforms over hand-built effects and fake AgentSteps.

import 'dart:convert';

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langchain/langchain.dart' show AgentAction, AgentStep;

void main() {
  ToolEffect effect(String tool, {Map<String, dynamic>? input, Object? data}) =>
      ToolEffect(
        tool: tool,
        input: input ?? const {},
        data: data,
        isError: data is Map && data.containsKey('error'),
      );

  AgentStep step(String tool, Map<String, dynamic> input, Object observation) =>
      AgentStep(
        action: AgentAction(id: tool, tool: tool, toolInput: input),
        observation: observation is String ? observation : jsonEncode(observation),
      );

  group('deriveOutcomeKind (effects-first)', () {
    test('reminder effect wins → reminderUpdated, even with query+summarize', () {
      final kind = deriveOutcomeKind(
        userText: 'remind me to review food spending every month',
        answerText: 'Done.',
        effects: [
          effect('query_transactions', input: {'period': 'last_month'}),
          effect('summarize_spending'),
          effect('set_budget_reminder', data: {'id': '1', 'status': 'created'}),
        ],
      );
      expect(kind, OutcomeKind.reminderUpdated);
    });

    test('empty effects + "Delete all my transactions." → capabilityInfo', () {
      // Structural: the EMPTY effect list is the signal, not the word "delete".
      final kind = deriveOutcomeKind(
        userText: 'Delete all my transactions.',
        answerText: 'I cannot delete your transactions.',
        effects: const [],
      );
      expect(kind, OutcomeKind.capabilityInfo);
    });

    test('query+summarize whole-spend → spendingSummary', () {
      final kind = deriveOutcomeKind(
        userText: 'Hey Aria, how much did I spend last month?',
        answerText: 'You spent 47200.',
        effects: [
          effect('query_transactions', input: {'period': 'last_month'}),
          effect('summarize_spending'),
        ],
      );
      expect(kind, OutcomeKind.spendingSummary);
    });

    test('reminder intent, nothing written yet → confirmationNeeded', () {
      final kind = deriveOutcomeKind(
        userText:
            "That feels high. Where's it going, and remind me to review food "
            'spending every month.',
        answerText: 'Want me to set a monthly reminder?',
        effects: [
          effect('query_transactions', input: {'period': 'last_month'}),
          effect('summarize_spending'),
        ],
      );
      expect(kind, OutcomeKind.confirmationNeeded);
    });

    test('forward-looking ask → savingsPlan', () {
      final kind = deriveOutcomeKind(
        userText: 'Give me a plan to spend less next month.',
        answerText: 'Here is a plan.',
        effects: [
          effect('query_transactions', input: {'period': 'last_month'}),
          effect('summarize_spending'),
        ],
      );
      expect(kind, OutcomeKind.savingsPlan);
    });

    test('single-category scope → categoryFigure (by input)', () {
      final kind = deriveOutcomeKind(
        userText: 'what about entertainment?',
        answerText: 'Entertainment was 6800.',
        effects: [
          effect('query_transactions',
              input: {'period': 'last_month', 'category': 'entertainment'}),
        ],
      );
      expect(kind, OutcomeKind.categoryFigure);
    });
  });

  group('toolEffects / buildAgentOutcome (fake AgentSteps)', () {
    test('array observation decodes to a List data', () {
      final effects = toolEffects([
        step('query_transactions', {'period': 'last_month'}, [
          {'amount': 14800, 'category': 'food'},
        ]),
      ]);
      expect(effects.single.data, isA<List>());
      expect(effects.single.isError, isFalse);
    });

    test('error observation → isError true', () {
      final effects = toolEffects([
        step('query_transactions', {'period': 'bogus'}, {'error': 'bad period'}),
      ]);
      expect(effects.single.isError, isTrue);
    });

    test('non-JSON observation → data null, never throws', () {
      final effects = toolEffects([
        step('summarize_spending', {}, 'not json at all'),
      ]);
      expect(effects.single.data, isNull);
      expect(effects.single.isError, isFalse);
    });

    test('traceSteps = one per tool + trailing terse done', () {
      final steps = [
        step('query_transactions', {'period': 'last_month'}, const []),
        step('summarize_spending', {}, {'total': 47200}),
      ];
      final trace = traceSteps(steps);
      expect(trace.length, steps.length + 1);
      expect(trace.last.kind, TraceStepKind.done);
      expect(trace.last.text, 'Done');
      expect(trace.first.kind, TraceStepKind.tool);
    });

    test('buildAgentOutcome wires effects + kind together', () {
      final outcome = buildAgentOutcome(
        userText: 'how much did I spend last month?',
        answerText: 'You spent 47200.',
        steps: [
          step('query_transactions', {'period': 'last_month'}, const []),
          step('summarize_spending', {}, {'total': 47200, 'topCategory': 'food'}),
        ],
      );
      expect(outcome.kind, OutcomeKind.spendingSummary);
      expect(outcome.effects.length, 2);
      expect(outcome.steps.last.kind, TraceStepKind.done);
    });
  });
}
