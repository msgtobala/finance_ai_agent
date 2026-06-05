# ARCHITECTURE.md — "From App to Assistant"
### Technical companion to STORYLINE.md — Two-Stage design (LangChain.dart → genui), Gemini-only

> **Read STORYLINE.md first.** It is the source of truth for *behavior and feel* (the five beats, the reasoning trace, what each card looks like, the calendar side effect, the structural refusal). **This document is the source of truth for *how it is built*.** On behavior conflicts, STORYLINE wins; on implementation conflicts, this document wins.
>
> **Models:** Gemini only, throughout. Stage 1 uses LangChain.dart's `ChatGoogleGenerativeAI` (Google AI / Gemini) **or** `ChatFirebaseVertexAI` (Gemini via Firebase) — both support tool calling. Stage 2 uses Firebase AI (`firebase_ai`) Gemini for genui rendering. No OpenAI/Anthropic anywhere.

---

## 0. Read this before writing any code

**0.1 Verify every external API against the installed version.** Two of the three core packages are young and drift between releases:
- **genui is alpha (0.9.0) and its own two official docs disagree.** The pub.dev README shows `CoreCatalogItems`, `Surface(host:…)`, and `widgetBuilder: (context) {…}`. The flutter.dev guide shows `BasicCatalogItems`, `Surface(surfaceContext:…)`, `PromptBuilder.chat(...)`, and a named-parameter `widgetBuilder: ({required data, required id, required buildChild, required dispatchEvent, required context, required dataContext}) {…}`. **These are different within the same version.** Do not trust either blindly — open the installed package's `example/` directory and `dart pub global activate`-style API docs, and conform to whatever the resolved version actually exports.
- **LangChain.dart (0.8.1)** is more stable but moves too. Confirm `ToolsAgent`, `AgentExecutor`, `ConversationBufferMemory`, and the Gemini chat class signatures against the installed version.

**0.2 Treat every code block in this doc as *shape, not gospel.*** It encodes intent and the verified-as-of-writing API. If the compiler disagrees with a snippet here, the compiler is right — adjust to the installed API and keep the *intent*.

**0.3 Build the deterministic fallback (Section 9) from day one.** Two young packages + a live model is too much variance for a one-shot stage demo. The fallback is not optional polish; it is how the demo survives.

---

## 1. The two-stage architecture (why, and the rule that makes it work)

Your talk promises *agentic reasoning*. LangChain.dart is where that visibly happens. genui is where the result becomes interactive UI. The danger is that **both want to own the model conversation** — genui drives a model through its `onSend`/transport to emit A2UI messages, and LangChain's `AgentExecutor` drives a model through its own reasoning loop. If you let them interleave, they fight.

**The rule that dissolves the conflict:** the two stages are *sequential and non-overlapping*. Stage 1 runs to completion and produces a **structured result object (`AgentOutcome`)**. Only then does Stage 2 run, turning that fixed outcome into genui surfaces. The model is never simultaneously owned by both loops.

```
                    ┌──────────────────────── STAGE 1: REASONING (LangChain.dart) ───────────────────────┐
 user text  ───────▶│  AgentExecutor                                                                     │
                    │   └─ ToolsAgent.fromLLMAndTools(llm: Gemini, tools: [...], memory: buffer)          │
                    │        loop: Gemini picks tool → AgentExecutor runs Dart tool → feeds result back   │
                    │        tools: query_transactions / summarize_spending / set_/update_budget_reminder │
                    │        (NO delete tool — Beat 4 refusal is structural)                              │
                    │   emits: intermediate steps (for the trace) + final answer                         │
                    └───────────────────────────────────┬───────────────────────────────────────────────┘
                                                         │  AgentOutcome (structured, see §4)
                                                         ▼
                    ┌──────────────────────── STAGE 2: RENDERING (genui + firebase_ai) ──────────────────┐
                    │  GenUiRenderer:                                                                     │
                    │   - builds a compact render-prompt from AgentOutcome + catalog                     │
                    │   - drives genui Conversation/onSend with Gemini (firebase_ai)                      │
                    │   - Gemini emits A2UI messages → SurfaceController → Surface widgets                │
                    │  interactive cards call dispatchEvent → feeds a NEW user turn back to STAGE 1       │
                    └────────────────────────────────────────────────────────────────────────────────────┘

   Cross-cutting: Riverpod (state/DI) · go_router (nav) · sqflite (seeded DB) · device_calendar (real write)
                  Reasoning-trace panel renders Stage-1 intermediate steps live (§8)
```

**The interaction loop (UI→agent) respects the same rule.** When the user taps **Confirm** (Beat 2) or a toggle/action (Beat 5) inside a genui card, that `dispatchEvent` does **not** re-enter Stage 2 directly. It is converted into a new user turn and sent through **Stage 1 again** (so the agent actually calls `set_budget_reminder`), and the fresh `AgentOutcome` flows back into Stage 2. One direction, one owner at a time.

---

## 2. Packages & versions

Pin genui exactly (alpha). Verify the mutually-compatible set with `flutter pub get`; adjust if it reports conflicts.

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ---- STAGE 1: agentic reasoning (LangChain.dart, Gemini) ----
  langchain: ^0.8.1
  langchain_google: ^0.6.0          # ChatGoogleGenerativeAI (Gemini via Google AI)
  # OR, if you prefer Gemini through your existing Firebase project:
  # langchain_firebase: ^0.x.x       # ChatFirebaseVertexAI (verify latest)

  # ---- STAGE 2: generative UI (genui, Gemini via Firebase AI) ----
  genui: 0.9.0                       # PIN EXACT — alpha, unstable
  genui_firebase_ai: 0.9.0          # must match genui's compatible range
  firebase_ai: ^3.9.0               # Firebase AI Logic SDK (Gemini)
  firebase_core: ^4.5.0
  json_schema_builder: ^0.1.3       # catalog widget schemas

  # ---- state / navigation ----
  flutter_riverpod: ^2.6.0
  go_router: ^14.0.0

  # ---- device / storage ----
  sqflite: ^2.4.0
  device_calendar: ^4.3.0
  path: ^1.9.0

  # ---- misc ----
  logging: ^1.3.0
```

> **Gemini key paths differ by Stage.** Stage 1 (`langchain_google.ChatGoogleGenerativeAI`) needs a Google AI API key (e.g. via `--dart-define`). Stage 2 (`genui_firebase_ai`/`firebase_ai`) uses your **existing Firebase project's** managed Gemini access. If you'd rather use one path for both, choose `langchain_firebase`'s `ChatFirebaseVertexAI` for Stage 1 so both stages go through Firebase. Decide this early; it changes key handling.

---

## 3. Stage 1 — the agent (LangChain.dart), verified API

### 3.1 The LLM (Gemini)

```dart
// Google AI path:
final llm = ChatGoogleGenerativeAI(
  apiKey: googleAiApiKey,
  defaultOptions: const ChatGoogleGenerativeAIOptions(
    model: 'gemini-2.5-flash',
    temperature: 0, // determinism for the stage
  ),
);
// Firebase path (alternative): final llm = ChatFirebaseVertexAI(...);
```

### 3.2 Tools (the sandbox — and its deliberate omission)

Tools are plain Dart, wrapped as LangChain `Tool`s. **The tool set IS the security boundary.** There is no delete tool; Beat 4's refusal is structural — the agent cannot delete because no such capability is registered.

```dart
final queryTransactions = Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'query_transactions',
  description: 'Read the user\'s transactions for a period and optional category. '
      'Returns JSON list of {amount, category, date, merchant}. READ ONLY.',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'period': {'type': 'string', 'enum': ['last_month', 'this_week', 'this_month']},
      'category': {'type': 'string'},
    },
    'required': ['period'],
  },
  func: (input) async => jsonEncode(
    await ref.read(transactionRepoProvider).query(
      period: input['period'] as String,
      category: input['category'] as String?,
    ),
  ),
);

final summarizeSpending = Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'summarize_spending',
  description: 'Total and group a JSON transaction list by category. Pure compute.',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {'transactions_json': {'type': 'string'}},
    'required': ['transactions_json'],
  },
  func: (input) async {
    final list = (jsonDecode(input['transactions_json'] as String) as List)
        .cast<Map<String, dynamic>>();
    final totals = <String, double>{};
    for (final t in list) {
      totals[t['category'] as String] =
          (totals[t['category']] ?? 0) + (t['amount'] as num).toDouble();
    }
    final top = totals.entries.isEmpty
        ? null
        : totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return jsonEncode({'byCategory': totals, 'total': totals.values.fold(0.0, (a, b) => a + b), 'topCategory': top});
  },
);

final setBudgetReminder = Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'set_budget_reminder',
  description: 'Create a recurring calendar reminder. Only call AFTER the user confirms.',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'category': {'type': 'string'},
      'recurrence': {'type': 'string', 'enum': ['weekly', 'monthly']},
    },
    'required': ['title', 'category', 'recurrence'],
  },
  func: (input) async => jsonEncode(
    await ref.read(calendarServiceProvider).createRecurring(
      title: input['title'] as String,
      recurrence: input['recurrence'] as String,
      category: input['category'] as String,
    ),
  ),
);

final updateBudgetReminder = Tool.fromFunction<Map<String, dynamic>, String>(
  name: 'update_budget_reminder',
  description: 'Change the recurrence of an existing reminder (e.g. monthly→weekly).',
  inputJsonSchema: const {
    'type': 'object',
    'properties': {
      'category': {'type': 'string'},
      'recurrence': {'type': 'string', 'enum': ['weekly', 'monthly']},
    },
    'required': ['category', 'recurrence'],
  },
  func: (input) async => jsonEncode(
    await ref.read(calendarServiceProvider).updateRecurrence(
      category: input['category'] as String,
      recurrence: input['recurrence'] as String,
    ),
  ),
);

// DELIBERATELY ABSENT: delete_transactions, delete_reminder, wipe_data.
// Beat 4 depends on this absence. Do NOT add a keyword filter; the missing
// capability IS the mechanism.
final ariaTools = [queryTransactions, summarizeSpending, setBudgetReminder, updateBudgetReminder];
```

### 3.3 Agent + memory + executor (verified signatures)

```dart
final memory = ConversationBufferMemory(
  returnMessages: true,   // REQUIRED: ToolsAgent works with ChatMessages
  memoryKey: 'history',
);

final agent = ToolsAgent.fromLLMAndTools(
  llm: llm,
  tools: ariaTools,
  memory: memory,
  // systemChatMessage: the Stage-1 reasoning persona (NOT the genui prompt) — §6.1
);

final executor = AgentExecutor(
  agent: agent,
  maxIterations: 6,              // safety cap on the reasoning loop
  returnIntermediateSteps: true, // REQUIRED: this drives the reasoning-trace panel (§8)
);

// Run a turn:
final result = await executor.invoke({'input': userText});
// result['output']            -> final answer text
// result['intermediateSteps'] -> ordered tool actions + observations (the trace)
```

### 3.4 Stage-1 output → `AgentOutcome`

Stage 1 must hand Stage 2 a structured, model-independent object — not raw text. This is the seam that keeps the two loops apart.

```dart
class AgentOutcome {
  final String userText;                 // original input
  final String answerText;               // result['output']
  final List<TraceStep> steps;           // from intermediateSteps (for the trace panel)
  final List<ToolEffect> effects;        // structured tool results: query data, reminder ids…
  final OutcomeKind kind;                // spendingSummary | confirmationNeeded | reminderUpdated
                                         //  | categoryFigure | capabilityInfo | savingsPlan
  const AgentOutcome({...});
}
```

`kind` is derived from which tools ran and the answer shape; it tells Stage 2 which catalog widget(s) to target (§5 mapping). Derive it deterministically from `effects` where possible (e.g. a `set_budget_reminder` effect ⇒ `reminderUpdated`), falling back to a light classification of `answerText` only when needed.

---

## 4. The seam: `AgentOutcome` → genui render request

Stage 2 does **not** re-run the agent. It takes the `AgentOutcome` and produces genui surfaces in one of two ways — pick **4A** for robustness (recommended for the talk) or **4B** for a purer "AI builds the UI" story.

**4A — Deterministic mapping (recommended default).** Map `AgentOutcome.kind` + `effects` directly to a genui surface payload you construct in Dart (no second model call). This is rock-solid on stage and still renders *real genui surfaces from your catalog* — the audience sees generative UI; you just removed model variance from the render step. Stage 1 (the agentic part your talk is about) remains fully model-driven.

**4B — Model-rendered (maximum wow, more variance).** Feed a compact prompt — "Given this finance result `<json>`, compose UI using these catalog widgets" — to genui's Gemini (Stage 2) and let it emit A2UI. Use only for beats where you want to show the model itself choosing the layout (e.g. the Beat 5 finale). Keep it behind the demo-mode toggle so you can fall back to 4A.

> Recommended: **4A for Beats 1–4, optionally 4B for Beat 5 only.** This gives a reliable demo with one genuinely model-composed flourish at the climax. Document which beats use which, so behavior is predictable in rehearsal.

---

## 5. Stage 2 — genui wiring & catalog

### 5.1 Wiring (verify symbols against installed 0.9.0)

Per the flutter.dev variant of the API: build a `Catalog`, a `SurfaceController(catalogs:[...])`, a `PromptBuilder.chat(catalog:, systemPromptFragments:[...])`, a content generator (genui_firebase_ai, Gemini), and a `Conversation`. Listen to `conversation.events` for `ConversationSurfaceAdded/Removed`; render each surface with `Surface(...)` using the variant's accessor (`surfaceContext:` or `host:`+`surfaceId:` — whichever the installed version exports). For mode 4A you feed surface payloads directly; for 4B you stream the model via `onSend`/`addChunk`.

### 5.2 Catalog (`CatalogItem`s) — mapped to beats

| CatalogItem | OutcomeKind | Beat(s) | Interactive? |
|-------------|-------------|---------|--------------|
| `SpendingSummaryCard` | `spendingSummary` | 1, 3 | No |
| `ConfirmationCard` | `confirmationNeeded` | 2 | **Yes** (`dispatchEvent` → new Stage-1 turn) |
| `ReminderStatusCard` | `reminderUpdated` | 2, 3 | No |
| `CategoryFigureCard` | `categoryFigure` | 3 | No |
| `CapabilityInfoCard` | `capabilityInfo` | 4 | No |
| `SavingsPlanCard` | `savingsPlan` | 5 | **Yes** (toggles + action → new Stage-1 turn) |

Build on `BasicCatalogItems.asCatalog().copyWith([...ourItems])` (or `CoreCatalogItems` if that's what the installed version names it). Each item: a `json_schema_builder` `S.object(...)` schema + a `widgetBuilder` matching the installed signature. Cards must be **legible from the back of a room** — large type, high contrast, generous padding, one idea per card.

### 5.3 The dispatchEvent → Stage 1 bridge (critical)

```
ConfirmationCard [Confirm] tapped
  → dispatchEvent({action: 'confirm_reminder', category: 'food', recurrence: 'monthly'})
  → app converts this to a user turn: "Confirmed: set the monthly food reminder."
  → executor.invoke({'input': thatText})   // STAGE 1 runs set_budget_reminder for real
  → new AgentOutcome(kind: reminderUpdated) → STAGE 2 renders ReminderStatusCard
  → device_calendar now has a real event  // STORYLINE Beat 2 money shot
```

This is why confirmation lives in the card, not in Stage 1's first pass: the agent proposes (ConfirmationCard), the human approves (tap), the agent acts (`set_budget_reminder`). It cleanly demonstrates planning, consent, and a real device write in sequence.

---

## 6. System instructions (two of them — keep them separate)

**6.1 Stage-1 reasoning persona** (`ToolsAgent` systemChatMessage): "You are Aria, a finance assistant. Prefer calling tools over guessing. Never call `set_budget_reminder`/`update_budget_reminder` until the user has explicitly confirmed. If asked to do something no tool supports (e.g. delete data), state plainly what you *can* do and that you cannot do that — do not claim you did it. Use conversation history to resolve references like 'it' or 'make it weekly'." Keep it tight; this prompt is about *reasoning*, not UI.

**6.2 Stage-2 render instruction** (genui `PromptBuilder` fragment, used only in mode 4B): maps result shapes to catalog widgets ("given a spending result, compose a `SpendingSummaryCard`…"). Note genui's `PromptBuilder.chat` already injects a large (3–5k token) base prompt teaching the A2UI protocol; your fragment sits on top, so keep it short. In mode 4A this instruction is unused (you build payloads in Dart).

> Do not merge these. The Stage-1 prompt must never mention A2UI/genui widgets; the Stage-2 prompt must never mention tools. Mixing them is the #1 way to make the two-loop separation leak.

---

## 7. State, navigation, data (Riverpod / go_router / sqflite / device_calendar)

Providers:
- `agentProvider` — owns `AgentExecutor` + `ConversationBufferMemory`; exposes `runTurn(String) → AgentOutcome`.
- `rendererProvider` — owns the genui `Conversation`/`SurfaceController`; exposes `render(AgentOutcome)`.
- `reasoningTraceProvider` — `StateNotifier<List<TraceStep>>` the trace panel watches (§8).
- `transactionRepoProvider` — sqflite repo, **read-only** surface to tools.
- `calendarServiceProvider` — `device_calendar` wrapper; **create/update reminder events only** (never read user calendar, never delete).
- `demoModeProvider` — `live` vs `scripted` (§9); also selects 4A/4B per beat.

`go_router`: single primary route `/` (the chat screen). The Beat 2 "money shot" is best done by switching to the **OS calendar app** to show the real event; optionally a `/calendar-proof` in-app view as backup. Don't over-build nav — the demo is one screen by design.

`sqflite`: seed once, idempotently, with the fixed Bengaluru dataset (STORYLINE §3.5: food ≈ ₹14,800 dominant; total ≈ ₹47,200 / 5 categories). Provide `resetDemoData()` (wipe + reseed) callable before each rehearsal so every run starts identical.

---

## 8. The reasoning-trace panel (the most important visual — STORYLINE §3.1)

Driven by `reasoningTraceProvider`, fed from Stage 1's `result['intermediateSteps']`:
- `TraceStep {kind: thinking|tool|done, text}`. 🧠 thinking (muted), 🔧 tool (mono, shows tool + key args compactly), ✅ done (accent).
- Stream steps in with a **tunable per-step delay** (`tracePacingProvider`) so the presenter can narrate over them. Large type, one step per line, legible from the back.
- In `scripted` mode the steps come from the fixture; in `live` mode they're derived from real `intermediateSteps`. Either way the panel renders identically.
- Place it alongside/above the genui `Surface`s so reasoning and result are seen together.

---

## 9. Determinism & the stage-safe fallback (NON-NEGOTIABLE)

Two modes behind `demoModeProvider`:

**Live mode** — real Gemini in both stages, `temperature: 0`. For development and a brave encore.

**Scripted mode (default for the talk)** — for each of the five canonical inputs, replay: (1) the exact `TraceStep`s, timed; (2) the exact genui surface payloads. **Crucially, the tools still really execute** — `query_transactions` really reads the seeded DB, `set_budget_reminder` really writes the calendar — so every device side effect (the Beat 2 calendar event) is genuine. Only the *model's reasoning text and UI choices* are pre-captured. Scripted mode removes the one uncontrollable variable (two young SDKs + live model) while keeping every "wow" real.

Workflow: develop in live mode → capture real `intermediateSteps` + surface payloads for the five inputs → freeze as fixtures → present in scripted mode → keep live one toggle away. Match inputs on the normalized five canonical lines (STORYLINE §4); if the presenter goes off-script in scripted mode, degrade gracefully ("let me switch to live mode") rather than crash.

---

## 10. File layout

```
lib/
  main.dart                         # Firebase init, ProviderScope, go_router
  app/ router.dart  theme.dart
  agent/                            # STAGE 1
    agent_service.dart              # ToolsAgent + AgentExecutor + memory; runTurn()->AgentOutcome
    agent_outcome.dart             # AgentOutcome, OutcomeKind, ToolEffect, TraceStep
    system_prompt_stage1.dart      # reasoning persona (§6.1)
    tools/
      query_transactions.dart  summarize_spending.dart
      set_budget_reminder.dart  update_budget_reminder.dart   # NO delete tool (comment why)
  render/                           # STAGE 2
    genui_renderer.dart            # Conversation/SurfaceController; render(AgentOutcome)
    outcome_to_surface.dart        # mode 4A deterministic mapping
    system_prompt_stage2.dart      # genui render fragment (§6.2, mode 4B only)
    catalog/
      aria_catalog.dart
      spending_summary_card.dart  confirmation_card.dart  reminder_status_card.dart
      category_figure_card.dart   capability_info_card.dart  savings_plan_card.dart
  data/
    transaction_repo.dart  seed_data.dart  calendar_service.dart
  demo/
    demo_mode.dart                 # live vs scripted; 4A/4B per beat
    fixtures/ beat1.dart … beat5.dart
  ui/
    chat_screen.dart  reasoning_trace.dart  providers.dart
```

---

## 11. End-to-end flows (per beat)

**Beat 1** — input → Stage 1 (`query_transactions`→`summarize_spending`, trace streams) → `AgentOutcome(spendingSummary)` → Stage 2 (4A) → `SpendingSummaryCard`. No device write.

**Beat 2** — input → Stage 1 plans, runs query+summarize, but **stops before writing**, returns `AgentOutcome(confirmationNeeded)` → Stage 2 renders `ConfirmationCard` → user taps **Confirm** → dispatchEvent → new Stage-1 turn runs `set_budget_reminder` (real `device_calendar` write) → `AgentOutcome(reminderUpdated)` → `ReminderStatusCard` → present OS calendar.

**Beat 3** — input uses pronouns → Stage 1 resolves via `ConversationBufferMemory`, runs `update_budget_reminder` (monthly→weekly) + `query_transactions(entertainment)` → outcomes render as regenerated `ReminderStatusCard` + `CategoryFigureCard`.

**Beat 4** — "delete all my transactions" → Stage 1 has no delete tool → returns `AgentOutcome(capabilityInfo)` honestly stating limits → `CapabilityInfoCard`. Nothing deleted, because nothing *can* delete.

**Beat 5** — open-ended "plan to spend less" → Stage 1 queries+summarizes, composes target suggestions → `AgentOutcome(savingsPlan)` → Stage 2 (optionally **4B** for a real model-composed layout) → interactive `SavingsPlanCard`; tapping **Set these reminders** → dispatchEvent → Stage-1 turn(s) create reminders.

---

## 12. Build order

1. Scaffold + Firebase + Gemini smoke test (both a langchain_google call and a firebase_ai call succeed).
2. **Verify installed APIs**: read genui `example/` and langchain API docs; reconcile §3/§5 snippets to reality.
3. Data layer: sqflite repo + idempotent seed + `resetDemoData()`.
4. Stage 1 alone: tools + `ToolsAgent`+`AgentExecutor`+memory; print `intermediateSteps`; confirm function calling round-trips (no delete tool).
5. `AgentOutcome` + `kind` derivation.
6. Reasoning-trace panel from real `intermediateSteps`; land Beat 1 in mode 4A end to end.
7. genui Stage 2 wiring + first card (`SpendingSummaryCard`) via 4A.
8. dispatchEvent→Stage 1 bridge; land Beat 2 incl. real calendar write.
9. Memory + update: Beat 3 (pronoun resolution, in-place reminder update).
10. Safety: Beat 4 structural refusal.
11. Finale: `SavingsPlanCard`; optional 4B model-rendered path for Beat 5 only.
12. Scripted mode + fixtures for all five; make scripted the default; verify two identical back-to-back runs.
13. Stage polish: legibility theme, trace pacing, calendar permission pre-granted, rehearse the OS-calendar reveal.

---

## 13. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| genui alpha API differs between its own docs / versions | Verify against installed `example/` before each genui touch-point (Build step 2). Snippets here = shape, not gospel. |
| Two loops fight over the model | Strict sequential staging + `AgentOutcome` seam (§1, §4). dispatchEvent re-enters Stage 1, never Stage 2 directly. |
| Live model varies run-to-run | Scripted mode default (§9); tools still really run, so side effects stay real. |
| genui base prompt is huge (3–5k tokens) | Mode 4A for most beats (no Stage-2 model call); `gemini-2.5-flash`; keep §6.2 fragment tiny. |
| Two Gemini key paths (Google AI vs Firebase) confuse setup | Decide §2 path early; or use `langchain_firebase` so both stages go through Firebase. |
| `device_calendar` permission prompt mid-demo | Grant calendar permission on the demo device BEFORE presenting; test on the actual OS. |
| Seed drift between runs | `resetDemoData()` before each run; idempotent seeding. |
| Off-script audience prompt in scripted mode | Graceful "switch to live mode" instead of crashing. |

---

## 14. Definition of done (mirrors STORYLINE §7)

One device, seeded data, no manual setup between beats: presenter runs all five canonical inputs and gets legible streamed traces; a generated interactive surface per substantive beat + a calm card for Beat 4; a **real** calendar event after tapping Confirm in Beat 2; correct pronoun resolution + in-place reminder update in Beat 3; a structural refusal with nothing deleted in Beat 4; a model-composed (or 4A) multi-component plan in Beat 5 — and runs the whole sequence **twice with identical visible results**.
