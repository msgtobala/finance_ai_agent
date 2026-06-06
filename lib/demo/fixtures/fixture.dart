// Scripted-mode fixture types + input matching (ARCHITECTURE §9).
//
// A fixture freezes, per canonical input, the model's REASONING TEXT (the trace
// steps, including the 🧠 thinking lines live mode can't produce) and the UI
// CHOICE (the outcome kind). It does NOT freeze tool results: [toolCalls] are
// executed for real by the scripted runner, so every device side effect (calendar
// writes) stays genuine and the surfaces are built from real data via the same 4A
// mapping. See scripted_agent_service.dart.

import '../../agent/agent_outcome.dart';

/// One tool the scripted runner really invokes (real DB read / calendar write).
/// `summarize_spending`'s `transactions_json` is injected at run time from the
/// preceding `query_transactions` result, so its [args] here can omit it.
class ScriptedToolCall {
  const ScriptedToolCall(this.tool, [this.args = const {}]);

  final String tool;
  final Map<String, dynamic> args;
}

/// A frozen beat: the inputs that map to it, the scripted trace, the tools to run
/// for real, and the resulting UI choice.
class BeatFixture {
  const BeatFixture({
    required this.matchers,
    required this.steps,
    required this.toolCalls,
    required this.kind,
    this.answerText = '',
  });

  /// Normalized inputs (see [normalizeInput]) that select this fixture — the
  /// canonical beat line, or a dispatch-bridge follow-up turn's exact text.
  final List<String> matchers;
  final List<TraceStep> steps;
  final List<ScriptedToolCall> toolCalls;
  final OutcomeKind kind;
  final String answerText;
}

/// Normalize an input for matching: trim, lowercase, collapse internal whitespace.
String normalizeInput(String input) =>
    input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
