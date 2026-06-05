# CLAUDE.md — "From App to Assistant" (Flutter agentic AI demo)

This file is loaded automatically by Claude Code. It is the project ruleset.

You are working on a Flutter demo app ("Aria", a finance assistant) for a 15–20 min
conference talk. Two spec docs are the source of truth — READ THEM BEFORE EDITING:
- STORYLINE.md  → behavior & feel (the five beats, the reasoning trace, the cards). Wins on behavior.
- ARCHITECTURE.md → how it's built (two-stage LangChain.dart → genui, Gemini-only). Wins on implementation.
If your change would contradict either doc, stop and flag it instead of silently diverging.

## Non-negotiables
- This is a LIVE STAGE DEMO. Determinism > cleverness. Never introduce randomness that
  changes on-screen output between runs. Reasoning temperature is 0.
- Build/maintain the two demo modes (live vs scripted) behind `demoModeProvider`. Scripted
  is the default for the talk. In scripted mode the TOOLS STILL REALLY RUN (real DB reads,
  real calendar writes) — only model reasoning text + UI choices are replayed from fixtures.
- There is NO delete tool, by design. Beat 4's refusal is structural (missing capability),
  NOT a keyword filter. Never add delete_transactions / delete_reminder / wipe_data, and
  never add code that pattern-matches "delete" to refuse. If asked to, refuse and cite this rule.

## Architecture: two stages, never overlapping
- STAGE 1 = reasoning. LangChain.dart `ToolsAgent.fromLLMAndTools(llm, tools, memory)` +
  `AgentExecutor(returnIntermediateSteps: true)`. Gemini via `ChatGoogleGenerativeAI`
  (langchain_google) or `ChatFirebaseVertexAI` (langchain_firebase). Produces a structured
  `AgentOutcome` (never raw text handed onward).
- STAGE 2 = rendering. genui (`Catalog`/`SurfaceController`/`Conversation`) turns the
  `AgentOutcome` into interactive `Surface` cards. Gemini via genui_firebase_ai/firebase_ai.
- The two NEVER own the model at the same time. Stage 1 fully completes → `AgentOutcome` →
  Stage 2. A genui card's `dispatchEvent` re-enters STAGE 1 as a new user turn — never
  Stage 2 directly.
- Keep the two system prompts separate: Stage-1 prompt talks about tools/reasoning ONLY and
  must never mention genui/A2UI/widgets; Stage-2 prompt talks about catalog widgets ONLY and
  must never mention tools. Do not merge them.

## Models: Gemini only
- No OpenAI, Anthropic, or other providers anywhere. Default model `gemini-2.5-flash`, temp 0.
- Respect the two key paths: Stage 1 (Google AI key via --dart-define) vs Stage 2 (Firebase-
  managed). Never hardcode keys or commit secrets. Prefer --dart-define / env.

## Alpha-package discipline (CRITICAL)
- `genui` is ALPHA (0.9.0) and its own docs disagree (pub.dev README vs flutter.dev guide:
  CoreCatalogItems vs BasicCatalogItems, Surface(host:) vs Surface(surfaceContext:), and two
  different `widgetBuilder` signatures). DO NOT trust any genui snippet (including ones in
  ARCHITECTURE.md) without checking the INSTALLED version's `example/` dir and exported API.
  When the compiler disagrees with the docs, the compiler wins — conform to the installed API,
  preserve the intent.
- PIN genui + genui_firebase_ai to EXACT versions (no caret). Don't run `flutter pub upgrade`
  on genui packages without re-verifying the demo afterward.
- Verify LangChain.dart symbols (`ToolsAgent`, `AgentExecutor`, `ConversationBufferMemory`,
  `Tool.fromFunction`, `ChatGoogleGenerativeAI`) against the installed version too.

## State / nav / data
- State + DI via flutter_riverpod. Key providers: agentProvider, rendererProvider,
  reasoningTraceProvider, transactionRepoProvider, calendarServiceProvider, demoModeProvider.
- Navigation via go_router; single primary route `/`. Don't over-build navigation.
- Data via sqflite, seeded idempotently with the fixed Bengaluru dataset in STORYLINE §3.5
  (food ≈ ₹14,800 dominant; total ≈ ₹47,200 / 5 categories). Always provide & maintain
  `resetDemoData()`. Never change seed values without updating STORYLINE.
- `transactionRepoProvider` is READ-ONLY to tools. `calendarServiceProvider` may only
  create/update reminder events — never read the user's calendar, never delete.

## The reasoning-trace panel = the hero visual
- Driven by reasoningTraceProvider from Stage-1 `intermediateSteps`. TraceStep kinds:
  thinking 🧠 / tool 🔧 / done ✅. Stream in with a tunable per-step delay (tracePacingProvider).
- Large type, one step per line, high contrast — legible from the back of a room. Don't bury it.

## genui catalog cards (map to OutcomeKind)
SpendingSummaryCard, ConfirmationCard (interactive), ReminderStatusCard, CategoryFigureCard,
CapabilityInfoCard, SavingsPlanCard (interactive). Build on BasicCatalogItems/CoreCatalogItems
(whichever the installed version exports) via copyWith. Each: json_schema_builder schema +
widgetBuilder matching the INSTALLED signature. Keep cards big and legible (stage props).

## Rendering mode per beat
- Mode 4A (deterministic Dart mapping AgentOutcome→surface) for Beats 1–4 — robust, still real genui.
- Mode 4B (model-composed via genui Gemini) allowed ONLY for the Beat 5 finale, behind the toggle.

## Code style
- Null-safe, modern Flutter. Small files per ARCHITECTURE.md §10 layout. No business logic in widgets.
- Wrap all tool/DB/calendar/model calls in try/catch; fail gracefully (demo must never hard-crash on stage).
- No localStorage-style hacks; no TODOs left in demo-path code. Comment the "no delete tool"
  omission explicitly so reviewers know it's intentional.
- Prefer editing existing files to match the spec over creating parallel implementations.

## When unsure
Ask or flag, citing the relevant STORYLINE/ARCHITECTURE section. Do not invent agent
frameworks, providers, tools, or catalog items beyond what the specs define.
