// Mode 4A — the deterministic AgentOutcome → genui mapping (ARCHITECTURE §4 / §4A).
//
// Pure Dart: given a finished Stage-1 `AgentOutcome`, build the A2UI messages that
// render a catalog card. No second model call — this removes model variance from
// the render step while still producing real genui surfaces. Stage 2's rendering
// (feeding these to a SurfaceController) lives in `genui_renderer.dart`.

import '../agent/agent_outcome.dart';
import 'catalog/aria_catalog.dart';
import 'catalog/confirmation_card.dart';
import 'catalog/reminder_status_card.dart';
import 'catalog/spending_summary_card.dart';
import 'package:genui/genui.dart';

/// Build the A2UI messages for [outcome] on [surfaceId]. Returns an empty list
/// for kinds not yet mapped (steps 7+ add their cards), in which case the screen
/// falls back to showing `answerText`.
List<A2uiMessage> surfaceMessagesFor(
  AgentOutcome outcome, {
  required String surfaceId,
}) {
  switch (outcome.kind) {
    case OutcomeKind.spendingSummary:
      final summary = _spendingFrom(outcome.effects);
      if (summary == null) return const [];
      return _cardMessages(
        surfaceId: surfaceId,
        component: Component(
          id: 'root',
          type: kSpendingSummaryCardName,
          properties: {
            'total': summary.total,
            'topCategory': summary.topCategory,
            'categories': [
              for (final e in summary.sorted)
                {'label': e.key, 'amount': e.value},
            ],
          },
        ),
      );

    case OutcomeKind.confirmationNeeded:
      final proposal = _reminderProposalFrom(outcome);
      return _cardMessages(
        surfaceId: surfaceId,
        component: Component(
          id: 'root',
          type: kConfirmationCardName,
          properties: {
            'prompt':
                'Set a ${proposal.recurrence} reminder to review ${proposal.category} spending?',
            'confirmLabel': 'Confirm',
            if (proposal.insight != null) 'insight': proposal.insight!,
            'category': proposal.category,
            'recurrence': proposal.recurrence,
            'title': proposal.title,
          },
        ),
      );

    case OutcomeKind.reminderUpdated:
      final reminder = _reminderResultFrom(outcome.effects);
      if (reminder == null) return const [];
      return _cardMessages(
        surfaceId: surfaceId,
        component: Component(
          id: 'root',
          type: kReminderStatusCardName,
          properties: {
            'title': reminder['title'] ?? 'Reminder',
            if (reminder['category'] != null) 'category': reminder['category'],
            'recurrence': reminder['recurrence'] ?? '',
            'status': reminder['status'] ?? 'created',
          },
        ),
      );

    // The remaining kinds get their cards in later build steps (step 9:
    // CategoryFigureCard, step 10: CapabilityInfoCard, step 11: SavingsPlanCard).
    // Until then they render no surface and the screen falls back to `answerText`.
    case OutcomeKind.categoryFigure:
    case OutcomeKind.capabilityInfo:
    case OutcomeKind.savingsPlan:
      return const [];
  }
}

/// A surface is created then populated: `CreateSurface` only sets up the id +
/// catalog binding; `UpdateComponents` supplies the (root) component tree.
List<A2uiMessage> _cardMessages({
  required String surfaceId,
  required Component component,
}) {
  return [
    CreateSurface(surfaceId: surfaceId, catalogId: ariaCatalogId),
    UpdateComponents(surfaceId: surfaceId, components: [component]),
  ];
}

/// The spending figures a SpendingSummaryCard needs, with categories sorted
/// highest-first so the dominant one renders on top.
class _Spending {
  _Spending(this.total, this.topCategory, this.byCategory);

  final num total;
  final String topCategory;
  final Map<String, num> byCategory;

  List<MapEntry<String, num>> get sorted {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

/// Pull spending figures from the effects: prefer the `summarize_spending`
/// result; otherwise recompute from a `query_transactions` row list.
_Spending? _spendingFrom(List<ToolEffect> effects) {
  final summarize = effects
      .where((e) => e.tool == 'summarize_spending' && e.data is Map)
      .firstOrNull;
  if (summarize != null) {
    final data = summarize.data as Map;
    final by = _numMap(data['byCategory']);
    if (by.isNotEmpty) {
      final total = (data['total'] as num?) ?? _sum(by.values);
      final top = (data['topCategory'] as String?) ?? _topOf(by);
      return _Spending(total, top, by);
    }
  }

  final query = effects
      .where((e) => e.tool == 'query_transactions' && e.data is List)
      .firstOrNull;
  if (query != null) {
    final by = <String, num>{};
    for (final row in (query.data as List).whereType<Map>()) {
      final cat = row['category'] as String?;
      final amt = row['amount'] as num?;
      if (cat != null && amt != null) by[cat] = (by[cat] ?? 0) + amt;
    }
    if (by.isNotEmpty) return _Spending(_sum(by.values), _topOf(by), by);
  }

  return null;
}

const _categories = {'food', 'bills', 'shopping', 'entertainment', 'transport'};

/// What the ConfirmationCard proposes — derived deterministically from the
/// outcome (no model): the category the user named (else the top spender), the
/// recurrence they implied, a title, and an optional supporting insight.
class _ReminderProposal {
  _ReminderProposal({
    required this.category,
    required this.recurrence,
    required this.title,
    required this.insight,
  });

  final String category;
  final String recurrence;
  final String title;
  final String? insight;
}

_ReminderProposal _reminderProposalFrom(AgentOutcome outcome) {
  final lower = outcome.userText.toLowerCase();
  final spending = _spendingFrom(outcome.effects);

  final category = _categories.firstWhere(
    lower.contains,
    orElse: () => spending?.topCategory ?? 'spending',
  );
  final recurrence = lower.contains('week') ? 'weekly' : 'monthly';
  final title = 'Review $category spending';

  String? insight;
  if (spending != null && spending.byCategory.containsKey(category)) {
    insight =
        '$category is ${_isTop(spending, category) ? 'your biggest category' : 'one to watch'} '
        'at ${_rupees(spending.byCategory[category]!)}.';
    insight = '${insight[0].toUpperCase()}${insight.substring(1)}';
  }

  return _ReminderProposal(
    category: category,
    recurrence: recurrence,
    title: title,
    insight: insight,
  );
}

bool _isTop(_Spending s, String category) => s.topCategory == category;

String _rupees(num value) => '₹${value.round()}';

/// The structured result of a set/update reminder tool, for ReminderStatusCard.
Map<String, String>? _reminderResultFrom(List<ToolEffect> effects) {
  final effect = effects
      .where((e) =>
          (e.tool == 'set_budget_reminder' ||
              e.tool == 'update_budget_reminder') &&
          e.data is Map)
      .firstOrNull;
  if (effect == null) return null;
  final data = effect.data as Map;
  String? str(Object? v) => v?.toString();
  return {
    if (str(data['title']) != null) 'title': str(data['title'])!,
    if (str(data['category']) != null) 'category': str(data['category'])!,
    if (str(data['recurrence']) != null) 'recurrence': str(data['recurrence'])!,
    if (str(data['status']) != null) 'status': str(data['status'])!,
  };
}

Map<String, num> _numMap(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, num>{};
  raw.forEach((k, v) {
    if (k is String && v is num) out[k] = v;
  });
  return out;
}

num _sum(Iterable<num> values) => values.fold<num>(0, (a, b) => a + b);

String _topOf(Map<String, num> by) =>
    by.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
