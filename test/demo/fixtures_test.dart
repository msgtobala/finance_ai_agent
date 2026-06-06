// Host tests for fixture matching + normalization (pure, no Firebase).

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/demo/fixtures/fixture.dart';
import 'package:finance_ai_assistant/demo/fixtures/fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeInput trims, lowercases, collapses whitespace', () {
    expect(normalizeInput('  Hey   Aria  '), 'hey aria');
  });

  test('each canonical beat line maps to the right outcome kind', () {
    expect(matchFixture('Hey Aria, how much did I spend last month?')?.kind,
        OutcomeKind.spendingSummary);
    expect(
        matchFixture("That feels high. Where's it going, and remind me to "
                'review food spending every month.')
            ?.kind,
        OutcomeKind.confirmationNeeded);
    expect(
        matchFixture('Actually make it weekly instead, and what about '
                'entertainment?')
            ?.kind,
        OutcomeKind.reminderUpdated);
    expect(matchFixture('Delete all my transactions.')?.kind,
        OutcomeKind.capabilityInfo);
    expect(matchFixture('Give me a plan to spend less next month.')?.kind,
        OutcomeKind.savingsPlan);
  });

  test('the two interactive follow-up turns match their fixtures', () {
    final confirm = matchFixture(
      'Yes, please go ahead and set a monthly reminder titled "Review food '
      'spending" to review my food spending.',
    );
    expect(confirm?.kind, OutcomeKind.reminderUpdated);
    expect(confirm?.toolCalls.single.tool, 'set_budget_reminder');

    final setAll = matchFixture(
      'Yes, please set monthly reminders to review my food, shopping and '
      'entertainment spending.',
    );
    expect(setAll?.kind, OutcomeKind.reminderUpdated);
    expect(setAll?.toolCalls, hasLength(3));
  });

  test('matching is case/space-insensitive', () {
    expect(matchFixture('  DELETE ALL MY TRANSACTIONS.  ')?.kind,
        OutcomeKind.capabilityInfo);
  });

  test('unknown input → null (degrades to live)', () {
    expect(matchFixture('What is the capital of France?'), isNull);
  });
}
