// Host test that the Beat 1 payload actually validates against the catalog.
//
// Feeds the mode-4A messages into a REAL genui SurfaceController (pure Dart — no
// Firebase, no widget pump) and asserts the surface registers with a 'root'
// component and that the controller reports no validation error. This proves the
// SpendingSummaryCard schema and the payload built in outcome_to_surface.dart
// agree, without rendering.

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/render/catalog/aria_catalog.dart';
import 'package:finance_ai_assistant/render/catalog/capability_info_card.dart';
import 'package:finance_ai_assistant/render/catalog/category_figure_card.dart';
import 'package:finance_ai_assistant/render/catalog/confirmation_card.dart';
import 'package:finance_ai_assistant/render/catalog/savings_plan_card.dart';
import 'package:finance_ai_assistant/render/catalog/spending_summary_card.dart';
import 'package:finance_ai_assistant/render/dispatch_bridge.dart';
import 'package:finance_ai_assistant/render/outcome_to_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// Drive the mode-4A components for [outcome] into [controller] as the renderer
/// does — one surface per component, ids prefixed with [prefix].
List<String> _renderInto(
  SurfaceController controller,
  AgentOutcome outcome,
  String prefix,
) {
  final components = surfaceComponentsFor(outcome);
  final ids = <String>[];
  for (var i = 0; i < components.length; i++) {
    final id = components.length == 1 ? prefix : '$prefix-$i';
    controller.handleMessage(CreateSurface(surfaceId: id, catalogId: ariaCatalogId));
    controller.handleMessage(
        UpdateComponents(surfaceId: id, components: [components[i]]));
    ids.add(id);
  }
  return ids;
}

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

    _renderInto(controller, outcome, 'beat1');
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

  test('ariaCatalog exposes CategoryFigureCard', () {
    expect(
      ariaCatalog.items.any((i) => i.name == kCategoryFigureCardName),
      isTrue,
    );
  });

  test('ariaCatalog exposes CapabilityInfoCard', () {
    expect(
      ariaCatalog.items.any((i) => i.name == kCapabilityInfoCardName),
      isTrue,
    );
  });

  test('ariaCatalog exposes SavingsPlanCard', () {
    expect(
      ariaCatalog.items.any((i) => i.name == kSavingsPlanCardName),
      isTrue,
    );
  });

  test('Beat 5 SavingsPlanCard payload validates on a real SurfaceController',
      () async {
    final controller = SurfaceController(catalogs: [ariaCatalog]);
    final errors = <Object>[];
    final sub = controller.onSubmit.listen(errors.add);

    final outcome = AgentOutcome(
      userText: 'Give me a plan to spend less next month.',
      answerText: '',
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
      kind: OutcomeKind.savingsPlan,
    );

    _renderInto(controller, outcome, 'plan');
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeSurfaceIds, contains('plan'));
    final definition = controller.registry.getSurface('plan');
    expect(definition?.components['root']?.type, kSavingsPlanCardName);
    expect(errors, isEmpty); // no validation error

    await sub.cancel();
  });

  test('Beat 4 CapabilityInfoCard payload validates on a real SurfaceController',
      () async {
    final controller = SurfaceController(catalogs: [ariaCatalog]);
    final errors = <Object>[];
    final sub = controller.onSubmit.listen(errors.add);

    final outcome = AgentOutcome(
      userText: 'Delete all my transactions.',
      answerText: '',
      steps: const [],
      effects: const [], // structural refusal: no tool ran
      kind: OutcomeKind.capabilityInfo,
    );

    _renderInto(controller, outcome, 'capability');
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeSurfaceIds, contains('capability'));
    final definition = controller.registry.getSurface('capability');
    expect(definition?.components['root']?.type, kCapabilityInfoCardName);
    expect(errors, isEmpty); // no validation error

    await sub.cancel();
  });

  test('Beat 3 CategoryFigureCard payload validates on a real SurfaceController',
      () async {
    final controller = SurfaceController(catalogs: [ariaCatalog]);
    final errors = <Object>[];
    final sub = controller.onSubmit.listen(errors.add);

    final outcome = AgentOutcome(
      userText: 'what about entertainment?',
      answerText: 'You spent 6800 on entertainment last month.',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'query_transactions',
          input: {'period': 'last_month', 'category': 'entertainment'},
          data: [
            {'amount': 649, 'category': 'entertainment'},
            {'amount': 199, 'category': 'entertainment'},
            {'amount': 1400, 'category': 'entertainment'},
            {'amount': 2100, 'category': 'entertainment'},
            {'amount': 1252, 'category': 'entertainment'},
            {'amount': 1200, 'category': 'entertainment'},
          ],
          isError: false,
        ),
      ],
      kind: OutcomeKind.categoryFigure,
    );

    _renderInto(controller, outcome, 'figure');
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeSurfaceIds, contains('figure'));
    final definition = controller.registry.getSurface('figure');
    expect(definition?.components['root']?.type, kCategoryFigureCardName);
    expect(errors, isEmpty); // no validation error

    await sub.cancel();
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

    _renderInto(controller, outcome, 'confirm');
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
