// The scripted-fixture registry + input matching (ARCHITECTURE §9).
//
// All seven frozen turns: the five canonical beat lines plus the two interactive
// follow-ups (Beat 2's [Confirm] tap, Beat 5's [Set these reminders] tap). The
// scripted runner matches an input here; an unmatched input degrades to live.

import 'beat1.dart';
import 'beat2.dart';
import 'beat3.dart';
import 'beat4.dart';
import 'beat5.dart';
import 'fixture.dart';

/// Every scripted fixture, in beat order.
const scriptedFixtures = <BeatFixture>[
  beat1Fixture,
  beat2Fixture,
  beat2ConfirmFixture,
  beat3Fixture,
  beat4Fixture,
  beat5Fixture,
  beat5SetAllFixture,
];

/// The fixture whose (normalized) matchers contain [input], or null if none —
/// in which case scripted mode falls back to the live agent.
BeatFixture? matchFixture(String input) {
  final normalized = normalizeInput(input);
  for (final fixture in scriptedFixtures) {
    for (final matcher in fixture.matchers) {
      if (normalizeInput(matcher) == normalized) return fixture;
    }
  }
  return null;
}
