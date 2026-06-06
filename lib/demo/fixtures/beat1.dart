// Beat 1 fixture — "how much did I spend last month?" (STORYLINE Beat 1).
// Read-only: query + summarize, no device write.

import '../../agent/agent_outcome.dart';
import 'fixture.dart';

const beat1Fixture = BeatFixture(
  matchers: ['Hey Aria, how much did I spend last month?'],
  steps: [
    TraceStep(kind: TraceStepKind.thinking, text: "I need last month's transactions"),
    TraceStep(kind: TraceStepKind.tool, text: 'query_transactions · period: last_month'),
    TraceStep(kind: TraceStepKind.thinking, text: 'Totalling and grouping by category'),
    TraceStep(kind: TraceStepKind.tool, text: 'summarize_spending'),
    TraceStep(kind: TraceStepKind.done, text: 'Done'),
  ],
  toolCalls: [
    ScriptedToolCall('query_transactions', {'period': 'last_month'}),
    ScriptedToolCall('summarize_spending'),
  ],
  kind: OutcomeKind.spendingSummary,
);
