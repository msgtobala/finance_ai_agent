// Beat 2's interactive catalog card (ARCHITECTURE §5.2/§5.3, STORYLINE Beat 2).
//
// The agent proposes a reminder but does NOT write it; this card asks the user to
// confirm. Tapping Confirm dispatches a `confirm_reminder` UI event, which the
// app's dispatch bridge turns into a NEW user turn that re-enters Stage 1 and
// actually calls set_budget_reminder (see render/dispatch_bridge.dart). The card
// never calls Stage 2 directly — it only emits an event.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Catalog item name used as the `component` discriminator in payloads.
const String kConfirmationCardName = 'ConfirmationCard';

/// The action name dispatched when Confirm is tapped. The bridge matches on this.
const String kConfirmReminderAction = 'confirm_reminder';

final _schema = S.object(
  description:
      'Asks the user to confirm setting up a recurring budget reminder before '
      'anything is written.',
  properties: {
    'prompt': S.string(description: 'The confirmation question to show.'),
    'confirmLabel': S.string(description: 'Label for the confirm button.'),
    'insight': S.string(description: 'An optional one-line supporting insight.'),
    'category': S.string(description: 'The spending category to review.'),
    'recurrence': S.string(
      description: 'How often to review.',
      enumValues: ['weekly', 'monthly'],
    ),
    'title': S.string(description: 'The reminder title.'),
  },
  required: ['prompt', 'category', 'recurrence', 'title'],
);

/// The Beat 2 confirmation card.
final CatalogItem confirmationCard = CatalogItem(
  name: kConfirmationCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final prompt = (data['prompt'] as String?) ?? 'Set this reminder?';
      final confirmLabel = (data['confirmLabel'] as String?) ?? 'Confirm';
      final insight = data['insight'] as String?;
      final category = (data['category'] as String?) ?? '';
      final recurrence = (data['recurrence'] as String?) ?? 'monthly';
      final title = (data['title'] as String?) ?? '';

      return _ConfirmationView(
        prompt: prompt,
        confirmLabel: confirmLabel,
        insight: insight,
        onConfirm: () => itemContext.dispatchEvent(
          UserActionEvent(
            name: kConfirmReminderAction,
            sourceComponentId: itemContext.id,
            context: {
              'category': category,
              'recurrence': recurrence,
              'title': title,
            },
          ),
        ),
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render confirmation.'),
        ),
      );
    }
  },
);

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.prompt,
    required this.confirmLabel,
    required this.insight,
    required this.onConfirm,
  });

  final String prompt;
  final String confirmLabel;
  final String? insight;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Set a reminder', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prompt,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            if (insight != null && insight!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                insight!,
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: Text(confirmLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  textStyle: textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
