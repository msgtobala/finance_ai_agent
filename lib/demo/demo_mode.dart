// Demo mode — live vs scripted (ARCHITECTURE §9, CLAUDE.md non-negotiables).
//
// SCRIPTED is the committed default for the talk: for each canonical input we
// replay the exact reasoning trace + UI choice, but the TOOLS STILL REALLY RUN
// (real DB reads, real calendar writes) — only the model's reasoning text and the
// outcome kind are pre-captured. LIVE runs the real Gemini agent and is one toggle
// away (development + a brave encore). Off-script input in scripted mode degrades
// to live rather than crashing (see scripted_agent_service.dart).
//
// (Layout §10 also earmarks this for "4A/4B per beat"; 4B is a later addition
// behind this same toggle and is intentionally out of scope for step 12.)

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DemoMode { scripted, live }

/// The active demo mode. Defaults to [DemoMode.scripted] — the deterministic path
/// the talk runs on. The AppBar toggle flips it; switching also resets the live
/// agent's conversation memory (see chat_screen) so a later live turn starts clean.
final demoModeProvider =
    NotifierProvider<DemoModeNotifier, DemoMode>(DemoModeNotifier.new);

class DemoModeNotifier extends Notifier<DemoMode> {
  @override
  DemoMode build() => DemoMode.scripted;

  void set(DemoMode mode) => state = mode;

  void toggle() =>
      state = state == DemoMode.scripted ? DemoMode.live : DemoMode.scripted;
}
