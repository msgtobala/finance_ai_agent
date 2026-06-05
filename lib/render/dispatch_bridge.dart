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

/// Convert one interaction-part JSON string into a Stage-1 user turn, or null if
/// it is not a `confirm_reminder` action.
String? confirmTurnForInteraction(String interaction) {
  try {
    final decoded = jsonDecode(interaction);
    if (decoded is! Map) return null;

    final action = decoded['action'];
    if (action is! Map) return null; // e.g. an {"error": ...} message
    if (action['name'] != kConfirmReminderAction) return null;

    final context = action['context'];
    if (context is! Map) return null;

    final category = context['category'] as String?;
    final recurrence = context['recurrence'] as String?;
    final title = context['title'] as String?;
    if (category == null || recurrence == null || title == null) return null;

    return 'Yes, please go ahead and set a $recurrence reminder titled '
        '"$title" to review my $category spending.';
  } catch (_) {
    return null;
  }
}
