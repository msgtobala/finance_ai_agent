import 'dart:convert';

import 'package:langchain/langchain.dart';

import '../../data/calendar_service.dart';

/// Changes the recurrence of an existing reminder (e.g. monthly → weekly) in
/// place. Update-only — it cannot create duplicates or delete.
Tool buildUpdateBudgetReminderTool(CalendarService calendar) {
  return Tool.fromFunction<Map<String, dynamic>, String>(
    name: 'update_budget_reminder',
    description:
        'Change the recurrence of an existing reminder for a category '
        '(e.g. monthly to weekly). Updates the same reminder in place.',
    inputJsonSchema: const {
      'type': 'object',
      'properties': {
        'category': {'type': 'string'},
        'recurrence': {
          'type': 'string',
          'enum': ['weekly', 'monthly'],
        },
      },
      'required': ['category', 'recurrence'],
    },
    func: (input) async {
      try {
        final result = await calendar.updateRecurrence(
          category: input['category'] as String,
          recurrence: input['recurrence'] as String,
        );
        return jsonEncode(result);
      } catch (e) {
        return jsonEncode({'error': 'update_budget_reminder failed: $e'});
      }
    },
  );
}
