import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_outcome.dart';
import '../agent/agent_service.dart';
import '../agent/scripted_agent_service.dart';
import '../data/calendar_service.dart';
import '../data/transaction_repo.dart';
import '../demo/demo_mode.dart';
import '../render/genui_renderer.dart';

/// DI hub (ARCHITECTURE §10). Stage-1 tools and the UI read shared services
/// from here. More providers (demo mode) are added in later build steps.

/// The seeded transaction database. READ-ONLY to the agent: the
/// `query_transactions` tool calls [TransactionRepo.query] only — never the
/// seed/reset write methods (CLAUDE.md sandbox boundary).
final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  final repo = TransactionRepo();
  ref.onDispose(repo.close);
  return repo;
});

/// Reminder calendar. Create/update reminder events only — never read the user
/// calendar, never delete. Step 8 wires the real device_calendar-backed
/// implementation (the Beat 2 money shot); the in-memory one stays available for
/// host tests / scripted mode behind the same [CalendarService] interface.
final calendarServiceProvider = Provider<CalendarService>((ref) {
  return DeviceCalendarService();
});

/// Stage 1 (live) — the LangChain agent. A single instance so conversation memory
/// persists across turns (Beat 3). Tools receive the repo (read-only) and the
/// calendar service by constructor injection.
final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService(
    repo: ref.read(transactionRepoProvider),
    calendar: ref.read(calendarServiceProvider),
  );
});

/// Stage 1 (scripted) — replays fixture traces + UI choices but really runs the
/// tools (real DB reads / calendar writes), sharing the same repo + calendar as
/// live. Off-script input degrades to the live agent (ARCHITECTURE §9).
final scriptedAgentServiceProvider = Provider<ScriptedAgentService>((ref) {
  return ScriptedAgentService(
    live: ref.read(agentServiceProvider),
    repo: ref.read(transactionRepoProvider),
    calendar: ref.read(calendarServiceProvider),
  );
});

/// The Stage-1 runner the UI talks to — scripted or live per [demoModeProvider]
/// (default scripted, the talk's deterministic path). Both implement [AgentRunner].
final activeAgentProvider = Provider<AgentRunner>((ref) {
  return switch (ref.watch(demoModeProvider)) {
    DemoMode.scripted => ref.read(scriptedAgentServiceProvider),
    DemoMode.live => ref.read(agentServiceProvider),
  };
});

/// Stage 2 — the genui renderer (single instance owning the SurfaceController).
final rendererProvider = Provider<GenUiRenderer>((ref) {
  final renderer = GenUiRenderer();
  ref.onDispose(renderer.dispose);
  return renderer;
});

/// Per-step delay for the reasoning-trace panel (ARCHITECTURE §8, STORYLINE §6).
/// Presenter-tunable so the trace can be sped up or slowed down per beat.
final tracePacingProvider =
    NotifierProvider<TracePacingNotifier, Duration>(TracePacingNotifier.new);

class TracePacingNotifier extends Notifier<Duration> {
  @override
  Duration build() => const Duration(milliseconds: 600);

  void setDelay(Duration delay) => state = delay;
}

/// The reasoning trace the panel watches. [ReasoningTraceNotifier.play] streams
/// the steps in one at a time with [tracePacingProvider] between each, so the
/// audience can read the agent thinking as it happens.
final reasoningTraceProvider =
    NotifierProvider<ReasoningTraceNotifier, List<TraceStep>>(
  ReasoningTraceNotifier.new,
);

class ReasoningTraceNotifier extends Notifier<List<TraceStep>> {
  @override
  List<TraceStep> build() => const [];

  /// Reveal [steps] one at a time, pausing [tracePacingProvider] between each.
  /// The first step appears immediately; the panel grows as it plays.
  Future<void> play(List<TraceStep> steps) async {
    state = const [];
    for (final step in steps) {
      state = [...state, step];
      if (step != steps.last) {
        await Future<void>.delayed(ref.read(tracePacingProvider));
      }
    }
  }

  void clear() => state = const [];
}
