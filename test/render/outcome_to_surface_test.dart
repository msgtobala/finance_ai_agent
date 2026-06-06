// Host tests for the mode-4A mapping. Pure Dart: AgentOutcome -> root component(s),
// no Firebase, no rendering.

import 'package:finance_ai_assistant/agent/agent_outcome.dart';
import 'package:finance_ai_assistant/render/catalog/capability_info_card.dart';
import 'package:finance_ai_assistant/render/catalog/category_figure_card.dart';
import 'package:finance_ai_assistant/render/catalog/confirmation_card.dart';
import 'package:finance_ai_assistant/render/catalog/reminder_status_card.dart';
import 'package:finance_ai_assistant/render/catalog/savings_plan_card.dart';
import 'package:finance_ai_assistant/render/catalog/spending_summary_card.dart';
import 'package:finance_ai_assistant/render/outcome_to_surface.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('spendingSummary -> a single SpendingSummaryCard component', () {
    final components = surfaceComponentsFor(spendingOutcome());
    expect(components, hasLength(1));

    final root = components.single;
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

    final root = surfaceComponentsFor(outcome).single;
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

    final root = surfaceComponentsFor(outcome).single;
    expect(root.type, kConfirmationCardName);
    expect(root.properties['category'], 'food');
    expect(root.properties['recurrence'], 'monthly');
    expect(root.properties['title'], 'Review food spending');
  });

  test('reminderUpdated (reminder only) -> a single ReminderStatusCard', () {
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

    final components = surfaceComponentsFor(outcome);
    expect(components, hasLength(1));
    final root = components.single;
    expect(root.type, kReminderStatusCardName);
    expect(root.properties['title'], 'Review food spending');
    expect(root.properties['recurrence'], 'monthly');
    expect(root.properties['status'], 'created');
  });

  test('categoryFigure standalone -> a single CategoryFigureCard', () {
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

    final root = surfaceComponentsFor(outcome).single;
    expect(root.type, kCategoryFigureCardName);
    expect(root.properties['category'], 'entertainment');
    expect(root.properties['amount'], 6800);
    expect(root.properties['period'], 'last month');
    expect(root.properties['count'], 6);
  });

  test('Beat 3 combined (reminder update + entertainment query) -> two cards, '
      'reminder then figure', () {
    final outcome = AgentOutcome(
      userText: 'Actually make it weekly instead, and what about entertainment?',
      answerText: 'Updated to weekly. Entertainment was 6800 last month.',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'update_budget_reminder',
          input: {'category': 'food', 'recurrence': 'weekly'},
          data: {
            'id': 'food',
            'title': 'Review food spending',
            'category': 'food',
            'recurrence': 'weekly',
            'status': 'updated',
          },
          isError: false,
        ),
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
      kind: OutcomeKind.reminderUpdated,
    );

    final components = surfaceComponentsFor(outcome);
    expect(components, hasLength(2));

    // Order: regenerated reminder card on top, then the entertainment figure.
    expect(components[0].type, kReminderStatusCardName);
    expect(components[0].properties['recurrence'], 'weekly');
    expect(components[0].properties['status'], 'updated');

    expect(components[1].type, kCategoryFigureCardName);
    expect(components[1].properties['category'], 'entertainment');
    expect(components[1].properties['amount'], 6800);
    expect(components[1].properties['count'], 6);
  });

  test('capabilityInfo (Beat 4, empty effects) -> one calm CapabilityInfoCard', () {
    // The structural refusal: no delete tool ran, so effects is empty. The card
    // content is deterministic and request-agnostic (no userText inspection).
    final outcome = AgentOutcome(
      userText: 'Delete all my transactions.',
      answerText: '',
      steps: const [],
      effects: const [],
      kind: OutcomeKind.capabilityInfo,
    );

    final root = surfaceComponentsFor(outcome).single;
    expect(root.type, kCapabilityInfoCardName);
    expect(root.properties['headline'], "Here's what I can do");
    final capabilities =
        (root.properties['capabilities'] as List).cast<String>();
    expect(capabilities, hasLength(2));
    expect(capabilities, contains('Read your spending'));
    expect(capabilities, contains('Create and update reminders'));
    expect(root.properties['limitation'], isNotNull);
  });

  test('savingsPlan (Beat 5) -> one SavingsPlanCard with deterministic targets',
      () {
    // query + summarize ran → spending available → a plan can be composed.
    final outcome = spendingOutcome();
    final planOutcome = AgentOutcome(
      userText: 'Give me a plan to spend less next month.',
      answerText: '',
      steps: const [],
      effects: outcome.effects,
      kind: OutcomeKind.savingsPlan,
    );

    final root = surfaceComponentsFor(planOutcome).single;
    expect(root.type, kSavingsPlanCardName);
    expect(root.properties['recurrence'], 'monthly');

    final targets =
        (root.properties['targets'] as List).cast<Map<String, Object?>>();
    // Discretionary categories only (food, shopping, entertainment) — not bills
    // or transport.
    expect(targets.map((t) => t['category']),
        ['food', 'shopping', 'entertainment']);
    final food = targets.firstWhere((t) => t['category'] == 'food');
    expect(food['current'], 14800);
    expect(food['target'], 12600); // 15% cut, rounded to ₹100
    expect(food['saving'], 2200);
  });

  test('savingsPlan with no spending data -> no components', () {
    final outcome = AgentOutcome(
      userText: 'plan to spend less',
      answerText: 'x',
      steps: const [],
      effects: const [],
      kind: OutcomeKind.savingsPlan,
    );
    expect(surfaceComponentsFor(outcome), isEmpty);
  });

  test('reminderUpdated with several reminder effects -> one card each (Beat 5 '
      'chain-back)', () {
    final outcome = AgentOutcome(
      userText: 'Yes, set monthly reminders for food, shopping and entertainment.',
      answerText: 'Done.',
      steps: const [],
      effects: const [
        ToolEffect(
          tool: 'set_budget_reminder',
          input: {'category': 'food', 'recurrence': 'monthly'},
          data: {
            'title': 'Review food spending',
            'category': 'food',
            'recurrence': 'monthly',
            'status': 'created',
          },
          isError: false,
        ),
        ToolEffect(
          tool: 'set_budget_reminder',
          input: {'category': 'shopping', 'recurrence': 'monthly'},
          data: {
            'title': 'Review shopping spending',
            'category': 'shopping',
            'recurrence': 'monthly',
            'status': 'created',
          },
          isError: false,
        ),
      ],
      kind: OutcomeKind.reminderUpdated,
    );

    final components = surfaceComponentsFor(outcome);
    expect(components, hasLength(2));
    expect(components.every((c) => c.type == kReminderStatusCardName), isTrue);
    expect(components[0].properties['category'], 'food');
    expect(components[1].properties['category'], 'shopping');
  });
}
