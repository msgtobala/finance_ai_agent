import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_service.dart';
import '../data/calendar_service.dart';
import '../data/transaction_repo.dart';

/// DI hub (ARCHITECTURE §10). Stage-1 tools and the UI read shared services
/// from here. More providers (renderer, reasoning trace, demo mode) are added
/// in later build steps.

/// The seeded transaction database. READ-ONLY to the agent: the
/// `query_transactions` tool calls [TransactionRepo.query] only — never the
/// seed/reset write methods (CLAUDE.md sandbox boundary).
final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  final repo = TransactionRepo();
  ref.onDispose(repo.close);
  return repo;
});

/// Reminder calendar. Create/update reminder events only — never read the user
/// calendar, never delete. Step 4 uses the in-memory implementation; step 8
/// swaps in a device_calendar-backed one behind the same interface.
final calendarServiceProvider = Provider<CalendarService>((ref) {
  return InMemoryCalendarService();
});

/// Stage 1 — the LangChain agent. A single instance so conversation memory
/// persists across turns (Beat 3). Tools receive the repo (read-only) and the
/// calendar service by constructor injection.
final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService(
    repo: ref.read(transactionRepoProvider),
    calendar: ref.read(calendarServiceProvider),
  );
});
