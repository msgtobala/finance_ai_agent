import 'dart:convert';

import 'package:langchain/langchain.dart';

import '../../data/calendar_service.dart';

/// Creates a recurring budget-review reminder. Create-only — there is no delete
/// counterpart. The system prompt instructs Aria to call this only after the
/// user has confirmed.
Tool buildSetBudgetReminderTool(CalendarService calendar) {
  return Tool.fromFunction<Map<String, dynamic>, String>(
    name: 'set_budget_reminder',
    description:
        'Create a recurring calendar reminder to review spending. Only call '
        'AFTER the user has asked for or confirmed the reminder.',
    inputJsonSchema: const {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'category': {'type': 'string'},
        'recurrence': {
          'type': 'string',
          'enum': ['weekly', 'monthly'],
        },
      },
      'required': ['title', 'category', 'recurrence'],
    },
    func: (input) async {
      try {
        final result = await calendar.createRecurring(
          title: input['title'] as String,
          category: input['category'] as String,
          recurrence: input['recurrence'] as String,
        );
        return jsonEncode(result);
      } catch (e) {
        return jsonEncode({'error': 'set_budget_reminder failed: $e'});
      }
    },
  );
}
