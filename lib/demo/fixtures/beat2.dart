// Beat 2 fixtures — the plan/propose turn, and the [Confirm]-tap follow-up turn.
//
// NOTE on the trace split: STORYLINE's Beat-2 trace shows set_budget_reminder +
// "Reminder created" inline, but our verified behavior (Stage-1 prompt: confirm
// first) splits it into a PROPOSE turn (the typed input → ConfirmationCard, no
// write) and a CONFIRM turn (the card's [Confirm] tap → the real write). The
// scripted fixtures mirror that real two-turn flow: beat2Fixture ends at the
// proposal (no write line — none happens), and beat2ConfirmFixture carries the
// write. This honors STORYLINE's interactive-confirm behavior over its idealized
// single-trace depiction (CLAUDE.md: STORYLINE wins on behavior).

import '../../agent/agent_outcome.dart';
import 'fixture.dart';

const beat2Fixture = BeatFixture(
  matchers: [
    "That feels high. Where's it going, and remind me to review food spending every month.",
  ],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'Two things: find the biggest category, then set a recurring reminder',
    ),
    TraceStep(kind: TraceStepKind.tool, text: 'query_transactions · period: last_month'),
    TraceStep(kind: TraceStepKind.tool, text: 'summarize_spending'),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: "Food is the largest at ₹14,800 — that's the one to watch",
    ),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: "I'll propose a monthly reminder and ask you to confirm",
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Proposing a reminder'),
  ],
  toolCalls: [
    ScriptedToolCall('query_transactions', {'period': 'last_month'}),
    ScriptedToolCall('summarize_spending'),
  ],
  kind: OutcomeKind.confirmationNeeded,
);

/// The follow-up turn produced by the ConfirmationCard's [Confirm] tap (see
/// dispatch_bridge `_confirmReminderTurn` with category=food, recurrence=monthly,
/// title="Review food spending"). This turn does the real calendar write.
const beat2ConfirmFixture = BeatFixture(
  matchers: [
    'Yes, please go ahead and set a monthly reminder titled "Review food spending" '
        'to review my food spending.',
  ],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'Confirmed — creating the monthly reminder',
    ),
    TraceStep(
      kind: TraceStepKind.tool,
      text: 'set_budget_reminder · title: Review food spending · recurrence: monthly',
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Reminder created'),
  ],
  toolCalls: [
    ScriptedToolCall('set_budget_reminder', {
      'title': 'Review food spending',
      'category': 'food',
      'recurrence': 'monthly',
    }),
  ],
  kind: OutcomeKind.reminderUpdated,
);
