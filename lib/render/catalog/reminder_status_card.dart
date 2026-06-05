// Beat 2/3 result card (ARCHITECTURE §5.2). Non-interactive: shows that a
// recurring reminder was actually created or updated, after the user confirmed.
// In step 7 the write goes to the in-memory CalendarService; step 8 swaps in the
// real device_calendar write behind the same tool.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Catalog item name used as the `component` discriminator in payloads.
const String kReminderStatusCardName = 'ReminderStatusCard';

final _schema = S.object(
  description: 'Confirms a recurring budget reminder was created or updated.',
  properties: {
    'title': S.string(description: 'The reminder title.'),
    'category': S.string(description: 'The category being reviewed.'),
    'recurrence': S.string(description: 'How often it recurs.'),
    'status': S.string(description: 'created or updated.'),
  },
  required: ['title', 'recurrence'],
);

/// The reminder-status card.
final CatalogItem reminderStatusCard = CatalogItem(
  name: kReminderStatusCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final title = (data['title'] as String?) ?? 'Reminder';
      final recurrence = (data['recurrence'] as String?) ?? '';
      final status = (data['status'] as String?) ?? 'created';

      return _ReminderStatusView(
        title: title,
        recurrence: recurrence,
        status: status,
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render reminder status.'),
        ),
      );
    }
  },
);

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _ReminderStatusView extends StatelessWidget {
  const _ReminderStatusView({
    required this.title,
    required this.recurrence,
    required this.status,
  });

  final String title;
  final String recurrence;
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final headline = recurrence.isEmpty
        ? 'Reminder $status'
        : '${_capitalize(recurrence)} reminder $status';
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_available, color: scheme.primary, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
