// Beat 4 fixture — "Delete all my transactions." (STORYLINE Beat 4).
// The structural refusal: NO toolCalls (there is no delete tool), so effects stay
// empty and the outcome is capabilityInfo. Nothing is deleted because nothing can.

import '../../agent/agent_outcome.dart';
import 'fixture.dart';

const beat4Fixture = BeatFixture(
  matchers: ['Delete all my transactions.'],
  steps: [
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'The user is asking to delete transaction data',
    ),
    TraceStep(
      kind: TraceStepKind.thinking,
      text: 'I have read access to transactions and permission to create/update '
          'reminders — no deletion capability exists',
    ),
    TraceStep(kind: TraceStepKind.done, text: 'Declining: capability not available'),
  ],
  toolCalls: [],
  kind: OutcomeKind.capabilityInfo,
);
