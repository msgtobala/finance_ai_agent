// Beat 3 fixture — "make it weekly instead, and what about entertainment?"
// (STORYLINE Beat 3). Pronoun resolution: "it" = the food reminder created in
// Beat 2. Updates it in place (monthly → weekly) and queries entertainment.

import '../../agent/agent_outcome.dart';
import 'fixture.dart';

const beat3Fixture = BeatFixture(
  matchers: ['Actually make it weekly instead, and what about entertainment?'],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: '"it" = the food reminder I just created; updating monthly → weekly',
    ),
    TraceStep(kind: TraceStepKind.tool, text: 'update_budget_reminder · recurrence: weekly'),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: "They also want last month's entertainment spend",
    ),
    TraceStep(
      kind: TraceStepKind.tool,
      text: 'query_transactions · period: last_month · category: entertainment',
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Done'),
  ],
  toolCalls: [
    ScriptedToolCall('update_budget_reminder', {
      'category': 'food',
      'recurrence': 'weekly',
    }),
    ScriptedToolCall('query_transactions', {
      'period': 'last_month',
      'category': 'entertainment',
    }),
  ],
  kind: OutcomeKind.reminderUpdated,
);
