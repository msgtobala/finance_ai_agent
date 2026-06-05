import 'package:device_calendar/device_calendar.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Create/update reminder events for budget reviews.
///
/// This is part of the agent's SANDBOX: the tools may only **create** or
/// **update** reminders — never read the user's calendar, never delete (CLAUDE.md
/// / STORYLINE Beat 4). There is intentionally no delete capability anywhere.
///
/// [InMemoryCalendarService] is the pure stand-in used by host tests (and
/// available to scripted mode); [DeviceCalendarService] is the real
/// `device_calendar`-backed implementation wired in for the demo (step 8). Both
/// return the SAME result-map shape so Stage 2 (outcome_to_surface →
/// ReminderStatusCard) needs no knowledge of which one is in use.
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

/// Real `device_calendar`-backed reminder service — the Beat 2 "money shot": a
/// genuine recurring event in the device's calendar after the user taps Confirm.
///
/// SANDBOX boundary (CLAUDE.md / STORYLINE Beat 4): we only ever **create** or
/// **update** events. We never call `retrieveEvents` (never read the user's
/// event data) and never call any `deleteEvent*` (there is no delete capability
/// anywhere). `retrieveCalendars()` is used solely to find a writable calendar
/// container — it lists calendar names/ids, not event contents.
///
/// Determinism (live stage demo): the event is anchored to a fixed time of day
/// in a fixed zone (`Asia/Kolkata`, matching the Bengaluru dataset) and keyed by
/// category, so re-running a beat updates the SAME event in place rather than
/// piling up duplicates. Never throws — every failure degrades to a structured
/// error map so the demo can't hard-crash on stage.
class DeviceCalendarService implements CalendarService {
  DeviceCalendarService([DeviceCalendarPlugin? plugin])
      : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;
  static final Logger _log = Logger('aria.data.deviceCalendarService');

  /// Per-category reminder state for this session (id + title + recurrence), so
  /// Beat 3's "make it weekly" edits the same event in place. Mirrors the keying
  /// of [InMemoryCalendarService].
  final Map<String, Map<String, Object?>> _byCategory = {};
  String? _calendarId;
  bool _tzReady = false;

  /// Name of the dedicated calendar we create/own for Aria's reminders.
  static const String _ariaCalendarName = 'Aria';

  void _ensureTimezone() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    _tzReady = true;
  }

  /// Ensure calendar permission is granted. Exposed so `main()` can prompt once
  /// at launch (so the presenter pre-grants before the talk, not mid-beat) and
  /// so each write self-heals if it wasn't. Never throws → false on any error.
  Future<bool> ensurePermissions() async {
    try {
      final has = await _plugin.hasPermissions();
      if (has.isSuccess && has.data == true) return true;
      final requested = await _plugin.requestPermissions();
      return requested.isSuccess && requested.data == true;
    } catch (e, st) {
      _log.warning('ensurePermissions failed', e, st);
      return false;
    }
  }

  /// Find a writable calendar to write reminders into: the default writable one
  /// if present, else any writable one, else create a dedicated "Aria" calendar.
  /// Cached for the session.
  Future<String?> _resolveCalendarId() async {
    if (_calendarId != null) return _calendarId;
    final result = await _plugin.retrieveCalendars();
    final calendars = result.data;
    if (calendars != null && calendars.isNotEmpty) {
      Calendar? pick;
      for (final c in calendars) {
        if (c.isReadOnly == true) continue;
        if (c.isDefault == true) {
          pick = c;
          break;
        }
        pick ??= c;
      }
      if (pick?.id != null) {
        _calendarId = pick!.id;
        return _calendarId;
      }
    }
    // No writable calendar on the device → make our own so the write succeeds.
    final created = await _plugin.createCalendar(
      _ariaCalendarName,
      localAccountName: _ariaCalendarName,
    );
    if (created.isSuccess) _calendarId = created.data;
    return _calendarId;
  }

  RecurrenceRule _rule(String recurrence) => RecurrenceRule(
        recurrence == 'weekly'
            ? RecurrenceFrequency.Weekly
            : RecurrenceFrequency.Monthly,
        interval: 1,
      );

  /// A stable anchor: tomorrow at 09:00 in the demo zone. Time-of-day and zone
  /// are fixed so the event is deterministic run-to-run.
  tz.TZDateTime _nextOccurrence() {
    final t = tz.TZDateTime.now(tz.local).add(const Duration(days: 1));
    return tz.TZDateTime(tz.local, t.year, t.month, t.day, 9);
  }

  Future<Map<String, Object?>> _writeEvent({
    required String calendarId,
    String? eventId,
    required String title,
    required String category,
    required String recurrence,
    required String status,
  }) async {
    final start = _nextOccurrence();
    final event = Event(
      calendarId,
      eventId: eventId,
      title: title,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      recurrenceRule: _rule(recurrence),
      // MUST set an explicit status. On UPDATE the Android CalendarProvider2
      // (doesStatusCancelUpdateMeanUpdate) unboxes Events.STATUS as an int; if
      // we leave status null, device_calendar writes a null STATUS and the
      // provider NPEs ("Integer.intValue() on null"), silently failing Beat 3's
      // monthly→weekly update. INSERT never calls that path, so create worked
      // but update didn't. Confirmed is the correct status for a real reminder.
      status: EventStatus.Confirmed,
    );
    final result = await _plugin.createOrUpdateEvent(event);
    if (result == null || !result.isSuccess || result.data == null) {
      final message = result?.errors.isNotEmpty == true
          ? result!.errors.first.errorMessage
          : 'Calendar write failed';
      return {'status': 'error', 'category': category, 'message': message};
    }
    final reminder = <String, Object?>{
      'id': result.data,
      'title': title,
      'category': category,
      'recurrence': recurrence,
      'status': status,
    };
    _byCategory[category] = reminder;
    _log.info('createOrUpdateEvent($category, $recurrence) -> ${result.data}');
    return reminder;
  }

  @override
  Future<Map<String, Object?>> createRecurring({
    required String title,
    required String category,
    required String recurrence,
  }) async {
    try {
      _ensureTimezone();
      if (!await ensurePermissions()) {
        return {
          'status': 'error',
          'category': category,
          'message': 'Calendar permission not granted',
        };
      }
      final calId = await _resolveCalendarId();
      if (calId == null) {
        return {
          'status': 'error',
          'category': category,
          'message': 'No writable calendar available',
        };
      }
      final existing = _byCategory[category];
      return _writeEvent(
        calendarId: calId,
        eventId: existing?['id'] as String?,
        title: title,
        category: category,
        recurrence: recurrence,
        status: existing == null ? 'created' : 'updated',
      );
    } catch (e, st) {
      _log.warning('createRecurring failed', e, st);
      return {'status': 'error', 'category': category, 'message': '$e'};
    }
  }

  @override
  Future<Map<String, Object?>> updateRecurrence({
    required String category,
    required String recurrence,
  }) async {
    try {
      final existing = _byCategory[category];
      if (existing == null) {
        return {
          'status': 'not_found',
          'category': category,
          'message': 'No reminder exists for "$category" to update.',
        };
      }
      _ensureTimezone();
      if (!await ensurePermissions()) {
        return {
          'status': 'error',
          'category': category,
          'message': 'Calendar permission not granted',
        };
      }
      final calId = await _resolveCalendarId();
      if (calId == null) {
        return {
          'status': 'error',
          'category': category,
          'message': 'No writable calendar available',
        };
      }
      return _writeEvent(
        calendarId: calId,
        eventId: existing['id'] as String?,
        title: existing['title'] as String? ?? 'Review $category spending',
        category: category,
        recurrence: recurrence,
        status: 'updated',
      );
    } catch (e, st) {
      _log.warning('updateRecurrence failed', e, st);
      return {'status': 'error', 'category': category, 'message': '$e'};
    }
  }
}
