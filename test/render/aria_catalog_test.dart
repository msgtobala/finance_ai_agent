// Host test that the Beat 1 payload actually validates against the catalog.
//
// Feeds the mode-4A messages into a REAL genui SurfaceController (pure Dart — no
// Firebase, no widget pump) and asserts the surface registers with a 'root'
// component and that the controller reports no validation error. This proves the
// SpendingSummaryCard schema and the payload built in outcome_to_surface.dart
// agree, without rendering.

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/render/catalog/aria_catalog.dart';
import 'package:finance_ai_assistant/render/catalog/confirmation_card.dart';
import 'package:finance_ai_assistant/render/catalog/spending_summary_card.dart';
import 'package:finance_ai_assistant/render/dispatch_bridge.dart';
import 'package:finance_ai_assistant/render/outcome_to_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Beat 1 payload validates on a real SurfaceController', () async {
    final controller = SurfaceController(catalogs: [ariaCatalog]);
    final errors = <Object>[];
    final sub = controller.onSubmit.listen(errors.add);

    final outcome = AgentOutcome(
      userText: 'how much did I spend last month?',
      answerText: 'You spent 47200.',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'summarize_spending',
          input: {},
          data: {
            'byCategory': {
              'food': 14800,
              'bills': 13000,
              'shopping': 9500,
              'entertainment': 6800,
              'transport': 3100,
            },
            'total': 47200,
            'topCategory': 'food',
          },
          isError: false,
        ),
      ],
      kind: OutcomeKind.spendingSummary,
    );

    for (final message in surfaceMessagesFor(outcome, surfaceId: 'beat1')) {
      controller.handleMessage(message);
    }
    // Let any async validation submissions settle.
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeSurfaceIds, contains('beat1'));

    final definition = controller.registry.getSurface('beat1');
    expect(definition, isNotNull);
    expect(definition!.components.containsKey('root'), isTrue);
    expect(definition.components['root']!.type, kSpendingSummaryCardName);

    // No validation error was reported back to the "AI".
    expect(errors, isEmpty);

    await sub.cancel();
  });

  test('ariaCatalog exposes SpendingSummaryCard under the shared catalogId', () {
    expect(ariaCatalog.catalogId, ariaCatalogId);
    expect(
      ariaCatalog.items.any((i) => i.name == kSpendingSummaryCardName),
      isTrue,
    );
  });

  test('ConfirmationCard payload validates and its Confirm tap bridges back to '
      'a Stage-1 turn', () async {
    final controller = SurfaceController(catalogs: [ariaCatalog]);
    final submissions = <ChatMessage>[];
    final sub = controller.onSubmit.listen(submissions.add);

    final outcome = AgentOutcome(
      userText: 'remind me to review food spending every month',
      answerText: 'Want me to set a monthly reminder?',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'summarize_spending',
          input: {},
          data: {
            'byCategory': {'food': 14800},
            'total': 14800,
            'topCategory': 'food',
          },
          isError: false,
        ),
      ],
      kind: OutcomeKind.confirmationNeeded,
    );

    for (final message in surfaceMessagesFor(outcome, surfaceId: 'confirm')) {
      controller.handleMessage(message);
    }
    await Future<void>.delayed(Duration.zero);

    // The card validated and registered.
    final definition = controller.registry.getSurface('confirm');
    expect(definition?.components['root']?.type, kConfirmationCardName);
    expect(submissions, isEmpty); // no validation error

    // Simulate the Confirm tap: the card would dispatch this event.
    controller.contextFor('confirm').handleUiEvent(
          UserActionEvent(
            name: kConfirmReminderAction,
            sourceComponentId: 'root',
            context: const {
              'category': 'food',
              'recurrence': 'monthly',
              'title': 'Review food spending',
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    // The tap surfaced on onSubmit and the bridge turns it into a Stage-1 turn.
    expect(submissions, hasLength(1));
    final interaction = submissions.single.parts.uiInteractionParts.single;
    final turn = confirmTurnForInteraction(interaction.interaction);
    expect(turn, isNotNull);
    expect(turn, contains('monthly'));
    expect(turn, contains('food'));

    await sub.cancel();
  });
}
