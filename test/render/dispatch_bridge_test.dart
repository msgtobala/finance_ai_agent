// Host tests for the dispatchEvent → Stage 1 bridge. Pure: a UI-interaction JSON
// string in, a Stage-1 user turn (or null) out.

import 'dart:convert';

import 'package:finance_ai_assistant/render/dispatch_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String interaction(Map<String, Object?> action) =>
      jsonEncode({'version': 'v0.9', 'action': action});

  test('confirm_reminder action → an explicit confirmation user turn', () {
    final turn = confirmTurnForInteraction(interaction({
      'name': 'confirm_reminder',
      'sourceComponentId': 'root',
      'context': {
        'category': 'food',
        'recurrence': 'monthly',
        'title': 'Review food spending',
      },
    }));

    expect(turn, isNotNull);
    expect(turn, contains('monthly'));
    expect(turn, contains('food'));
    expect(turn, contains('Review food spending'));
  });

  test('set_savings_reminders action → a turn naming each category', () {
    final turn = confirmTurnForInteraction(interaction({
      'name': 'set_savings_reminders',
      'sourceComponentId': 'root',
      'context': {
        'categories': 'food,shopping,entertainment',
        'recurrence': 'monthly',
      },
    }));

    expect(turn, isNotNull);
    expect(turn, contains('monthly'));
    expect(turn, contains('food'));
    expect(turn, contains('shopping'));
    expect(turn, contains('entertainment'));
  });

  test('set_savings_reminders with no accepted categories → null', () {
    final turn = confirmTurnForInteraction(interaction({
      'name': 'set_savings_reminders',
      'context': {'categories': '', 'recurrence': 'monthly'},
    }));
    expect(turn, isNull);
  });

  test('an error message on the same stream → null', () {
    final errorMsg = jsonEncode({
      'version': 'v0.9',
      'error': {'code': 'VALIDATION_FAILED', 'message': 'bad'},
    });
    expect(confirmTurnForInteraction(errorMsg), isNull);
  });

  test('an unknown action name → null', () {
    final turn = confirmTurnForInteraction(interaction({
      'name': 'some_other_action',
      'context': {'category': 'food'},
    }));
    expect(turn, isNull);
  });

  test('missing context fields → null (no half-built turn)', () {
    final turn = confirmTurnForInteraction(interaction({
      'name': 'confirm_reminder',
      'context': {'category': 'food'}, // no recurrence/title
    }));
    expect(turn, isNull);
  });

  test('malformed JSON → null, never throws', () {
    expect(confirmTurnForInteraction('not json'), isNull);
  });
}
