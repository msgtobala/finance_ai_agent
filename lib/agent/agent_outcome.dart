// The Stage-1 → Stage-2 seam (ARCHITECTURE.md §3.4 / §4).
//
// Stage 1 (the LangChain agent) hands Stage 2 (genui rendering) a structured,
// model-independent object — `AgentOutcome` — NOT raw text. Everything in this
// file is pure Dart: it calls no model, touches no Firebase and no genui. It is
// the boundary between the two stages, so it can be unit-tested on the host and
// keeps the two loops strictly non-overlapping.

import 'dart:convert';

import 'package:langchain/langchain.dart' show AgentStep;

/// Which catalog card Stage 2 should target (ARCHITECTURE.md §3.4 / §5.2).
enum OutcomeKind {
  spendingSummary, // Beat 1 — whole-month spend → SpendingSummaryCard
  confirmationNeeded, // Beat 2 first pass — propose a reminder → ConfirmationCard
  reminderUpdated, // Beat 2 confirm / Beat 3 — reminder written → ReminderStatusCard
  categoryFigure, // Beat 3 follow-up — one category → CategoryFigureCard
  capabilityInfo, // Beat 4 — honest limits, no tool ran → CapabilityInfoCard
  savingsPlan, // Beat 5 — forward plan → SavingsPlanCard
}

/// Visual kind of one reasoning-trace line (ARCHITECTURE.md §8 / STORYLINE §3.1).
enum TraceStepKind { thinking, tool, done }

/// One line in the reasoning-trace panel. The step-6 panel renders these; here
/// we only build the list from Stage 1's intermediate steps.
class TraceStep {
  const TraceStep({required this.kind, required this.text});

  final TraceStepKind kind;
  final String text;
}

/// One tool call's structured result, lifted out of an [AgentStep].
///
/// [data] is the tool observation decoded from JSON (a Map or a List), or null
/// if the observation was not JSON. This is exactly what the Stage-2 4A mapper
/// reads to build a card payload (e.g. a `summarize_spending` effect's [data]
/// feeds SpendingSummaryCard; a reminder effect's [data] feeds ReminderStatusCard).
class ToolEffect {
  const ToolEffect({
    required this.tool,
    required this.input,
    required this.data,
    required this.isError,
  });

  /// Lift an [AgentStep] into a [ToolEffect], decoding its observation JSON.
  /// Never throws: a non-JSON observation yields `data: null`.
  factory ToolEffect.fromStep(AgentStep step) {
    Object? data;
    try {
      data = jsonDecode(step.observation);
    } catch (_) {
      data = null; // observation wasn't JSON — keep it structured-but-empty
    }
    final isError = data is Map && data.containsKey('error');
    return ToolEffect(
      tool: step.action.tool,
      input: step.action.toolInput,
      data: data,
      isError: isError,
    );
  }

  final String tool;
  final Map<String, dynamic> input;
  final Object? data;
  final bool isError;
}

/// The structured handoff from Stage 1 to Stage 2 (ARCHITECTURE.md §3.4).
class AgentOutcome {
  const AgentOutcome({
    required this.userText,
    required this.answerText,
    required this.steps,
    required this.effects,
    required this.kind,
  });

  final String userText; // original input
  final String answerText; // result['output']
  final List<TraceStep> steps; // for the trace panel (§8)
  final List<ToolEffect> effects; // structured tool results
  final OutcomeKind kind; // which card Stage 2 targets (§5 mapping)
}

/// Map each intermediate step to a structured [ToolEffect].
List<ToolEffect> toolEffects(List<AgentStep> steps) =>
    steps.map(ToolEffect.fromStep).toList(growable: false);

/// Build the trace lines: one `tool` step per tool call, then a trailing `done`
/// step carrying the final answer.
///
/// We do NOT synthesize `thinking` (🧠) lines here: LangChain's `action.log` for
/// a Gemini tool call is just boilerplate ("Invoking: `tool` with `args`") that
/// duplicates the tool line and dumps the full arguments — noise, not reasoning.
/// The genuine 🧠 narration (the short STORYLINE lines) is authored as fixtures
/// in scripted mode (step 12); the panel renders all three kinds, this builder
/// just emits the deterministic tool/done lines for live mode.
List<TraceStep> traceSteps(List<AgentStep> steps) {
  return <TraceStep>[
    for (final s in steps)
      TraceStep(kind: TraceStepKind.tool, text: _compactCall(s)),
    // The ✅ line is a terse marker (STORYLINE Beat 1: "✅ Done"); the actual
    // answer is conveyed by the rendered card, or by the screen's `answerText`
    // fallback for kinds without a card yet.
    const TraceStep(kind: TraceStepKind.done, text: 'Done'),
  ];
}

/// Compact one tool call into "tool(key: val, …)" for the trace line, truncating
/// long values (e.g. the full transactions JSON) so the line stays legible.
String _compactCall(AgentStep step) {
  final args = step.action.toolInput.entries
      .map((e) => '${e.key}: ${_truncate('${e.value}')}')
      .join(', ');
  return '${step.action.tool}($args)';
}

String _truncate(String value, [int max = 40]) =>
    value.length <= max ? value : '${value.substring(0, max)}…';

/// Assemble a complete [AgentOutcome] from a finished Stage-1 turn. Pure: no
/// model, no Firebase, no genui.
AgentOutcome buildAgentOutcome({
  required String userText,
  required String answerText,
  required List<AgentStep> steps,
}) {
  final effects = toolEffects(steps);
  return AgentOutcome(
    userText: userText,
    answerText: answerText,
    steps: traceSteps(steps),
    effects: effects,
    kind: deriveOutcomeKind(
      userText: userText,
      answerText: answerText,
      effects: effects,
    ),
  );
}

const _reminderTools = {'set_budget_reminder', 'update_budget_reminder'};
const _categories = {
  'food',
  'bills',
  'shopping',
  'entertainment',
  'transport',
};

/// Derive which catalog card Stage 2 targets — deterministically, with no model.
///
/// Effects-first: the structural rules (1 and 3) are driven purely by which
/// tools actually ran. The light text heuristics in rules 2/4/5 are UI-routing
/// hints explicitly sanctioned by §3.4 ("light classification … only when
/// needed"); they are NOT a safety filter. In particular, Beat 4's refusal lands
/// on `capabilityInfo` via rule 3 — the EMPTY effect list is the signal, never
/// the word "delete" — so the CLAUDE.md no-keyword-filter rule is preserved.
OutcomeKind deriveOutcomeKind({
  required String userText,
  required String answerText,
  required List<ToolEffect> effects,
}) {
  final lower = userText.toLowerCase();
  final ranTools = effects.map((e) => e.tool).toSet();

  // 1. A reminder was actually written → the result is the reminder's status.
  if (ranTools.intersection(_reminderTools).isNotEmpty) {
    return OutcomeKind.reminderUpdated;
  }

  // 2. User asked to be reminded, but nothing was written yet → propose + confirm.
  if (lower.contains('remind')) {
    return OutcomeKind.confirmationNeeded;
  }

  // 3. No tool ran at all → the agent answered from its own limits (Beat 4).
  //    Structural: the empty effect list is the signal, not any keyword.
  if (effects.isEmpty) {
    return OutcomeKind.capabilityInfo;
  }

  // 4. Forward-looking ask → a savings plan (Beat 5).
  if (lower.contains('plan') ||
      lower.contains('spend less') ||
      lower.contains('next month')) {
    return OutcomeKind.savingsPlan;
  }

  // 5. Scoped to a single category → a category figure (Beat 3 follow-up).
  final scopedByInput = effects.any(
    (e) =>
        e.tool == 'query_transactions' &&
        (e.input['category'] as String?)?.isNotEmpty == true,
  );
  final scopedByText = _categories.any(lower.contains);
  if (scopedByInput || scopedByText) {
    return OutcomeKind.categoryFigure;
  }

  // 6/7. Otherwise a whole-spend summary (Beat 1) — the safe default.
  return OutcomeKind.spendingSummary;
}
