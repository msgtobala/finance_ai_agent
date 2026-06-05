// Host tests for the mode-4A mapping. Pure Dart: AgentOutcome -> A2UI messages,
// no Firebase, no rendering.

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/render/catalog/aria_catalog.dart';
import 'package:finance_ai_assistant/render/catalog/confirmation_card.dart';
import 'package:finance_ai_assistant/render/catalog/reminder_status_card.dart';
import 'package:finance_ai_assistant/render/catalog/spending_summary_card.dart';
import 'package:finance_ai_assistant/render/outcome_to_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  AgentOutcome spendingOutcome() => AgentOutcome(
        userText: 'how much did I spend last month?',
        answerText: 'You spent 47200.',
        steps: const [],
        effects: const [
          ToolEffect(
            tool: 'query_transactions',
            input: {'period': 'last_month'},
            data: null,
            isError: false,
          ),
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

  test('spendingSummary -> CreateSurface + UpdateComponents(SpendingSummaryCard)',
      () {
    final messages =
        surfaceMessagesFor(spendingOutcome(), surfaceId: 'surface-1');

    expect(messages, hasLength(2));

    final create = messages[0] as CreateSurface;
    expect(create.surfaceId, 'surface-1');
    expect(create.catalogId, ariaCatalogId);

    final update = messages[1] as UpdateComponents;
    final root = update.components.single;
    expect(root.id, 'root');
    expect(root.type, kSpendingSummaryCardName);
    expect(root.properties['total'], 47200);
    expect(root.properties['topCategory'], 'food');

    final categories =
        (root.properties['categories'] as List).cast<Map<String, Object?>>();
    expect(categories, hasLength(5));
    // Sorted highest-first: food leads.
    expect(categories.first['label'], 'food');
    expect(categories.first['amount'], 14800);
    expect(categories.last['label'], 'transport');
  });

  test('falls back to query rows when summarize effect is absent', () {
    final outcome = AgentOutcome(
      userText: 'spend last month',
      answerText: '',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'query_transactions',
          input: {'period': 'last_month'},
          data: [
            {'amount': 14800, 'category': 'food'},
            {'amount': 6800, 'category': 'entertainment'},
          ],
          isError: false,
        ),
      ],
      kind: OutcomeKind.spendingSummary,
    );

    final update =
        surfaceMessagesFor(outcome, surfaceId: 's').last as UpdateComponents;
    final root = update.components.single;
    expect(root.properties['total'], 21600);
    expect(root.properties['topCategory'], 'food');
  });

  test('confirmationNeeded -> ConfirmationCard with derived proposal', () {
    final outcome = AgentOutcome(
      userText:
          "That feels high. Where's it going, and remind me to review food "
          'spending every month.',
      answerText: 'Want me to set a monthly reminder to review food spending?',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'summarize_spending',
          input: {},
          data: {
            'byCategory': {'food': 14800, 'transport': 3100},
            'total': 17900,
            'topCategory': 'food',
          },
          isError: false,
        ),
      ],
      kind: OutcomeKind.confirmationNeeded,
    );

    final root = (surfaceMessagesFor(outcome, surfaceId: 's').last
            as UpdateComponents)
        .components
        .single;
    expect(root.type, kConfirmationCardName);
    expect(root.properties['category'], 'food');
    expect(root.properties['recurrence'], 'monthly');
    expect(root.properties['title'], 'Review food spending');
  });

  test('reminderUpdated -> ReminderStatusCard from the reminder effect', () {
    final outcome = AgentOutcome(
      userText: 'Yes, set the monthly food reminder.',
      answerText: 'Done — monthly reminder created.',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'set_budget_reminder',
          input: {'title': 'Review food spending', 'recurrence': 'monthly'},
          data: {
            'id': 'food',
            'title': 'Review food spending',
            'category': 'food',
            'recurrence': 'monthly',
            'status': 'created',
          },
          isError: false,
        ),
      ],
      kind: OutcomeKind.reminderUpdated,
    );

    final root = (surfaceMessagesFor(outcome, surfaceId: 's').last
            as UpdateComponents)
        .components
        .single;
    expect(root.type, kReminderStatusCardName);
    expect(root.properties['title'], 'Review food spending');
    expect(root.properties['recurrence'], 'monthly');
    expect(root.properties['status'], 'created');
  });

  test('kinds without a card yet -> no messages', () {
    for (final kind in [
      OutcomeKind.capabilityInfo,
      OutcomeKind.categoryFigure,
      OutcomeKind.savingsPlan,
    ]) {
      final outcome = AgentOutcome(
        userText: '',
        answerText: 'x',
        steps: const [],
        effects: const [],
        kind: kind,
      );
      expect(surfaceMessagesFor(outcome, surfaceId: 's'), isEmpty,
          reason: '$kind should not render a surface yet');
    }
  });
}
