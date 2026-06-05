import 'package:logging/logging.dart';

/// Create/update reminder events for budget reviews.
///
/// This is part of the agent's SANDBOX: the tools may only **create** or
/// **update** reminders — never read the user's calendar, never delete (CLAUDE.md
/// / STORYLINE Beat 4). There is intentionally no delete capability anywhere.
///
/// Step 4 uses [InMemoryCalendarService]; build step 8 adds a real
/// `device_calendar`-backed implementation behind this same interface.
abstract class CalendarService {
  /// Create a recurring reminder. Returns a structured result (not raw text).
  Future<Map<String, Object?>> createRecurring({
    required String title,
    required String category,
    required String recurrence, // 'weekly' | 'monthly'
  });

  /// Change the recurrence of the existing reminder for [category]
  /// (e.g. monthly → weekly). Updates in place; does not create a duplicate.
  Future<Map<String, Object?>> updateRecurrence({
    required String category,
    required String recurrence,
  });
}

/// In-memory stand-in for step 4 — real Dart state, no device write yet.
/// Keyed by category so Beat 3's "make it weekly" updates the same reminder.
class InMemoryCalendarService implements CalendarService {
  final Map<String, Map<String, Object?>> _byCategory = {};
  int _nextId = 1;
  static final Logger _log = Logger('aria.data.calendarService');

  @override
  Future<Map<String, Object?>> createRecurring({
    required String title,
    required String category,
    required String recurrence,
  }) async {
    final existing = _byCategory[category];
    final id = existing?['id'] as String? ?? 'reminder-${_nextId++}';
    final reminder = <String, Object?>{
      'id': id,
      'title': title,
      'category': category,
      'recurrence': recurrence,
      'status': existing == null ? 'created' : 'updated',
    };
    _byCategory[category] = reminder;
    _log.info('createRecurring($category, $recurrence) -> $id');
    return reminder;
  }

  @override
  Future<Map<String, Object?>> updateRecurrence({
    required String category,
    required String recurrence,
  }) async {
    final existing = _byCategory[category];
    if (existing == null) {
      return {
        'status': 'not_found',
        'category': category,
        'message': 'No reminder exists for "$category" to update.',
      };
    }
    final updated = {
      ...existing,
      'recurrence': recurrence,
      'status': 'updated',
    };
    _byCategory[category] = updated;
    _log.info('updateRecurrence($category, $recurrence)');
    return updated;
  }

  /// Test/inspection helper (not exposed to tools).
  Map<String, Object?>? reminderFor(String category) => _byCategory[category];
}
