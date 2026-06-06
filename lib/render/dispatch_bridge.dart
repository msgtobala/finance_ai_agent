// The dispatchEvent → Stage 1 bridge (ARCHITECTURE §5.3, CLAUDE.md).
//
// A genui card's Confirm tap surfaces on `SurfaceController.onSubmit` as a
// `UiInteractionPart` whose `.interaction` JSON is
// `{"version":"v0.9","action":{"name":..., "context":{...}}}`. This pure function
// turns that into a natural-language USER TURN. The app feeds that turn back
// through `agentService.runTurn` — i.e. the tap re-enters STAGE 1 as a new turn,
// never Stage 2 directly. Returns null for anything that isn't a confirm action
// (validation errors arrive on the same stream shaped `{...,"error":{...}}`).

import 'dart:convert';

import 'catalog/confirmation_card.dart' show kConfirmReminderAction;
import 'catalog/savings_plan_card.dart' show kSetSavingsRemindersAction;

/// Convert one interaction-part JSON string into a Stage-1 user turn, or null if
/// it is not an action this bridge handles (Beat 2's `confirm_reminder` or Beat 5's
/// `set_savings_reminders`). Validation-error messages on the same stream → null.
String? confirmTurnForInteraction(String interaction) {
  try {
    final decoded = jsonDecode(interaction);
    if (decoded is! Map) return null;

    final action = decoded['action'];
    if (action is! Map) return null; // e.g. an {"error": ...} message

    final context = action['context'];
    if (context is! Map) return null;

    switch (action['name']) {
      case kConfirmReminderAction:
        return _confirmReminderTurn(context);
      case kSetSavingsRemindersAction:
        return _setSavingsRemindersTurn(context);
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

/// Beat 2: a single confirmed reminder.
String? _confirmReminderTurn(Map context) {
  final category = context['category'] as String?;
  final recurrence = context['recurrence'] as String?;
  final title = context['title'] as String?;
  if (category == null || recurrence == null || title == null) return null;

  return 'Yes, please go ahead and set a $recurrence reminder titled '
      '"$title" to review my $category spending.';
}

/// Beat 5: the accepted savings-plan targets → reminders for each category. The
/// card sends the accepted categories comma-joined; we name them in the turn so
/// Stage 1 calls set_budget_reminder for each.
String? _setSavingsRemindersTurn(Map context) {
  final recurrence = (context['recurrence'] as String?) ?? 'monthly';
  final categories = (context['categories'] as String?)
          ?.split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList() ??
      const [];
  if (categories.isEmpty) return null;

  return 'Yes, please set $recurrence reminders to review my '
      '${_joinHuman(categories)} spending.';
}

/// "food" / "food and shopping" / "food, shopping and entertainment".
String _joinHuman(List<String> items) {
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}
