// Beat 5 fixtures — the finale plan turn, and the [Set these reminders]-tap
// follow-up turn (all three targets accepted). (STORYLINE Beat 5.)

import '../../agent/agent_outcome.dart';
import 'fixture.dart';

const beat5Fixture = BeatFixture(
  matchers: ['Give me a plan to spend less next month.'],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: "I'll base a plan on last month's actual spending",
    ),
    TraceStep(kind: TraceStepKind.tool, text: 'query_transactions · period: last_month'),
    TraceStep(kind: TraceStepKind.tool, text: 'summarize_spending'),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'Food and shopping have the most room to cut; propose targets',
    ),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'Composing a plan the user can act on',
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Done'),
  ],
  toolCalls: [
    ScriptedToolCall('query_transactions', {'period': 'last_month'}),
    ScriptedToolCall('summarize_spending'),
  ],
  kind: OutcomeKind.savingsPlan,
);

/// The follow-up turn produced by the SavingsPlanCard's [Set these reminders] tap
/// with all targets accepted (see dispatch_bridge `_setSavingsRemindersTurn` with
/// categories food,shopping,entertainment and recurrence monthly). Creates all
/// three reminders for real. A different toggle selection produces different text
/// → no match → graceful degrade to live.
const beat5SetAllFixture = BeatFixture(
  matchers: [
    'Yes, please set monthly reminders to review my food, shopping and '
        'entertainment spending.',
  ],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'Setting up the reminders you accepted',
    ),
    TraceStep(
      kind: TraceStepKind.tool,
      text: 'set_budget_reminder · category: food · recurrence: monthly',
    ),
    TraceStep(
      kind: TraceStepKind.tool,
      text: 'set_budget_reminder · category: shopping · recurrence: monthly',
    ),
    TraceStep(
      kind: TraceStepKind.tool,
      text: 'set_budget_reminder · category: entertainment · recurrence: monthly',
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Reminders created'),
  ],
  toolCalls: [
    ScriptedToolCall('set_budget_reminder', {
      'title': 'Review food spending',
      'category': 'food',
      'recurrence': 'monthly',
    }),
    ScriptedToolCall('set_budget_reminder', {
      'title': 'Review shopping spending',
      'category': 'shopping',
      'recurrence': 'monthly',
    }),
    ScriptedToolCall('set_budget_reminder', {
      'title': 'Review entertainment spending',
      'category': 'entertainment',
      'recurrence': 'monthly',
    }),
  ],
  kind: OutcomeKind.reminderUpdated,
);
