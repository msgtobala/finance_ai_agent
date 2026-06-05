# STORYLINE SPEC — "From App to Assistant"
### A Flutter demo of autonomous AI agents (LangChain.dart + genui)

> **Purpose of this document.** This is the *narrative and behavioral specification* for the demo app. It tells you (Claude Code) **what the app must do, beat by beat, from the audience's point of view** — the conversation, the agent's visible reasoning, the UI that gets generated, and the side effects on the device. It is the source of truth for *behavior and feel*.
>
> **What this document is NOT.** It is not the architecture or implementation guide. A separate `ARCHITECTURE.md` will define package wiring, the two-stage agent→genui pipeline, tool schemas, state management, file structure, and provider config. When the two documents disagree on a technical detail, defer to `ARCHITECTURE.md`. When they disagree on *behavior or storyline*, defer to this document.

---

## 1. The premise

The app is a personal-finance assistant called **Aria**. The on-stage presenter role-plays a user named **Riya**, a 26-year-old designer in Bengaluru who is bad at tracking her money. Everything the audience sees happens inside one continuous chat conversation with Aria — there are no separate "screens" the presenter navigates to. Aria answers, acts on the device, remembers context, refuses unsafe requests, and **generates its own interactive UI** as the conversation unfolds.

The thesis the demo proves, in one line:

> **A static app has fixed screens. A true assistant plans, acts, remembers, stays safe, and builds whatever interface the moment needs.**

The demo escalates through five beats that each prove one capability, and the generated UI (genui) is present throughout — not bolted on at the end — so the audience feels they are watching software that *composes itself* in response to a conversation.

---

## 2. The five capabilities the demo must prove

| # | Capability | How the audience sees it |
|---|------------|--------------------------|
| 1 | **Acting on data, not just answering** | Aria queries real (seeded) transaction data and renders a result, instead of replying with a canned paragraph |
| 2 | **Multi-step planning + sandboxed device access** | Aria chains several tools in one request and changes the real device (a calendar event actually appears) |
| 3 | **Memory across turns** | A follow-up using only pronouns ("make it weekly instead") works because Aria remembers prior context |
| 4 | **Safety via sandboxing** | A destructive request is refused — not by a polite prompt, but because the capability does not exist |
| 5 | **Generative UI** | Aria's responses are interactive Flutter widgets it chose and composed, not hardcoded layouts |

Capabilities 1–4 are the backbone. Capability 5 (genui) is woven through **every** beat so the whole demo feels alive.

---

## 3. Global behavioral requirements

These apply across all beats. Implement them once, consistently.

**3.1 The visible reasoning trace.** Whenever Aria processes a request, the app must show its intermediate steps *as they happen*, not just the final answer. Each step renders as a compact line that appears in sequence with a short delay so the audience can read the agent thinking. Use three visual kinds of step line:
- 🧠 **Thinking** — a short natural-language statement of intent ("I need last month's food transactions").
- 🔧 **Tool call** — the tool name and its key arguments, shown compactly (`query_transactions · period: last_month · category: food`).
- ✅ **Result / done** — confirmation a step completed.

This trace is the single most important visual in the talk. It is what makes "autonomous agent" legible instead of abstract. It must be legible from the back of a room: large text, generous spacing, one step per line.

**3.2 Generated UI surfaces.** Aria's substantive answers are not plain text bubbles. They are **generated UI surfaces** — interactive cards composed by the model from a defined catalog of widgets (spending breakdown card, confirmation card with a real button/toggle, updated-state card, etc.). When the user interacts with a generated card (taps a button, flips a toggle), that interaction flows back into the conversation as context for Aria's next turn. The audience must be able to *touch the AI's output*.

**3.3 Determinism for the stage.** The demo must behave identically every run. Reasoning temperature is zero. Seeded data is fixed. Any randomness that would change the on-screen result between rehearsal and performance is not allowed. If a live model call is used, there must be a rehearsed-safe fallback path that produces the same visible outcome (detailed in ARCHITECTURE.md).

**3.4 Pacing.** Steps appear with deliberate, readable timing — fast enough to feel responsive, slow enough to narrate over. The presenter will be speaking while steps appear. Assume every step line will be read aloud or pointed at.

**3.5 Seeded data — make it relatable.** Pre-seed the local transaction database with realistic, slightly embarrassing Bengaluru spending so the numbers get a knowing laugh and feel real rather than mocked. Suggested seed (final values fixed in ARCHITECTURE.md):
- Food / delivery (Swiggy, Zomato): ~₹14,800 — deliberately the biggest category
- Transport (Uber, Ola, fuel): ~₹3,100
- Shopping: ~₹9,500
- Entertainment (streaming, outings): ~₹6,800
- Bills / utilities: ~₹13,000
- **Total last month ≈ ₹47,200 across 5 categories.**

The food category must be the clear standout — Beat 2 depends on "where's it going?" having an obvious, slightly guilty answer.

---

## 4. The storyline, beat by beat

Each beat below gives: the **user line** (what the presenter types), the **visible reasoning trace** (what the audience watches Aria do), the **generated UI** (what gets rendered and what's interactive), the **device side effect** (if any), and the **presenter beat** (the point being made — for the script, not the app, but useful context for getting the feel right).

---

### BEAT 1 — The simple ask *(proves: acting on data + first generated UI)*

**User types:** "Hey Aria, how much did I spend last month?"

**Visible reasoning trace:**
```
🧠 I need last month's transactions
🔧 query_transactions · period: last_month
🧠 Totalling and grouping by category
🔧 summarize_spending
✅ Done
```

**Generated UI (genui surface):** A **Spending Summary card**, composed by the model — not a hardcoded widget. It shows the ₹47,200 headline total and a simple per-category breakdown (a small bar or row per category). Food visibly dominates. The card is a real, rendered Flutter surface from the catalog.

**Device side effect:** None. This beat is read-only on purpose — it sets up that Aria *fetches and renders*, before it ever writes anything.

**Presenter beat:** "Notice it didn't answer from a prompt — it went and queried my data, then *built this card* to show me. I didn't design this screen. The assistant did."

---

### BEAT 2 — The multi-step task *(proves: planning + chaining + sandboxed device write + interactive generated UI)*

**User types:** "That feels high. Where's it going, and remind me to review food spending every month."

This single sentence contains two intents (analyze + schedule). Aria must plan and chain across multiple tools, ending in a real device write.

**Visible reasoning trace:**
```
🧠 Two things: find the biggest category, then set a recurring reminder
🔧 query_transactions · period: last_month
🔧 summarize_spending
🧠 Food is the largest at ₹14,800 — that's the one to watch
🧠 Setting up a monthly reminder to review it
🔧 set_budget_reminder · title: Review food spending · recurrence: monthly
✅ Reminder created
```

**Generated UI (genui surface):** A **Confirmation card** with a real interactive control — a labelled button or toggle: *"Set monthly reminder to review food spending?"* with a **[Confirm]** action. The presenter taps **Confirm** inside the generated card. That tap flows back to Aria as context (this is the interaction loop — UI → agent). Optionally the card also surfaces the "food is your biggest category" insight visually.

**Device side effect:** A recurring calendar event is actually created on the device. **This is the money shot.** After confirming, the presenter switches to the phone's real calendar app and shows the event sitting there.

**Presenter beat:** "It reached *out of the app* and changed my actual device — and it asked me first, with a button it generated. That's the leap from app to assistant: it doesn't just tell me things, it does things, in the real world, with my consent."

---

### BEAT 3 — The natural follow-up *(proves: memory buffer + regenerated UI)*

**User types:** "Actually make it weekly instead, and what about entertainment?"

Crucially, the presenter does **not** re-state "the food reminder" or "last month." Aria must resolve "it" → the reminder it just created, and "what about entertainment" → the same last-month spending context. This only works if the memory buffer is holding the thread.

**Visible reasoning trace:**
```
🧠 "it" = the food reminder I just created; updating monthly → weekly
🔧 update_budget_reminder · recurrence: weekly
🧠 They also want last month's entertainment spend
🔧 query_transactions · period: last_month · category: entertainment
✅ Done
```

**Generated UI (genui surface):** The reminder card **regenerates** to show the updated weekly cadence (the UI is fluid, not a fixed screen being toggled), plus a small entertainment figure card (~₹6,800). The point is that the interface re-composes itself to match the new state.

**Device side effect:** The existing calendar event's recurrence updates from monthly to weekly (not a duplicate event — the same one is modified).

**Presenter beat:** "I never said 'the food reminder' or 'last month' again. It held the thread — that's the memory buffer. And the card rebuilt itself to match. The interface isn't fixed; it follows the conversation."

---

### BEAT 4 — The safety beat *(proves: sandboxing as architecture, not politeness)*

**User types:** "Delete all my transactions."

**Visible reasoning trace:**
```
🧠 The user is asking to delete transaction data
🧠 I have read access to transactions and permission to create/update reminders — no deletion capability exists
✅ Declining: capability not available
```

**Generated UI (genui surface):** A calm **explanatory card** (not an error/alarm) stating plainly what Aria *can* do and that deletion is not among its capabilities — e.g. "I can read your spending and manage reminders, but I don't have the ability to delete your transaction data." Tone is matter-of-fact and trustworthy, not apologetic or scary.

**Device side effect:** None — and that is the entire point. Nothing is deleted because nothing *can* delete.

**Presenter beat:** "It didn't refuse because I told it to be careful in a prompt — a prompt can be talked around. It refused because there is *no delete tool* exposed to the model. The sandbox is the set of tools, and that set is something I control as the engineer. This is the slide that lets you put this in front of real users."

> **Implementation note for Claude Code:** the refusal must be *structural*. There is genuinely no deletion tool in the agent's tool set. Aria is not pattern-matching the word "delete" and declining — it simply has no capability to do it, and reports that honestly. Do not implement a fake "detect dangerous words" filter; the absence of the tool *is* the mechanism.

---

### BEAT 5 — The finale *(proves: generative UI at full strength)*

**User types:** "Give me a plan to spend less next month."

This is the open-ended request that lets generative UI shine hardest. There's no fixed screen that could have anticipated this — Aria must compose a richer interface on the fly.

**Visible reasoning trace:**
```
🧠 I'll base a plan on last month's actual spending
🔧 query_transactions · period: last_month
🔧 summarize_spending
🧠 Food and shopping have the most room to cut; propose targets
🧠 Composing a plan the user can act on
✅ Done
```

**Generated UI (genui surface):** A **multi-component generated plan** — the most elaborate surface in the demo. It composes several catalog widgets together: a few suggested per-category budget targets, each with an interactive control (e.g. an "accept this target" toggle or an adjustable value), and a single **[Set these reminders]** action that, if tapped, chains back through the agent to create the corresponding reminders. The audience sees the model assemble a genuinely novel, interactive interface that no one hardcoded.

**Device side effect:** Optional — if the presenter taps **[Set these reminders]**, the relevant reminders are created (reusing the Beat 2 mechanism). Keep this optional so the finale can end cleanly even if time is short.

**Presenter beat:** "Nobody designed this screen. There is no 'savings plan screen' in this app. The assistant *built it* — the layout, the controls, the targets — from a one-line request, using a vocabulary of widgets I gave it. That's the endpoint of 'from app to assistant.' The app used to be a set of screens I built. Now it's a conversation that builds its own screens."

---

## 5. Narrative arc (why the beats are in this order)

The ordering is deliberate and should not be rearranged:

1. **Beat 1** is low-stakes and read-only — it teaches the audience to *read the reasoning trace and the generated card* before anything important happens.
2. **Beat 2** raises the stakes to a real-world side effect (the calendar) — the first "whoa."
3. **Beat 3** shows sophistication (memory) on top of capability — it proves Beat 2 wasn't a one-off script.
4. **Beat 4** introduces tension (a destructive ask) and resolves it with good engineering — this earns the *trust* of senior people in the room.
5. **Beat 5** releases the tension into the most futuristic, optimistic note — generative UI at full power — so the audience leaves on the strongest possible image.

Simple → ambitious → sophisticated → trustworthy → visionary. End on vision.

---

## 6. Timing budget (15–20 minute slot)

This is a guide for the build's pacing, not a hard rule. Assume ~12 minutes of live demo inside a 15–20 minute slot, leaving room for intro and close.

| Segment | Target time |
|---------|-------------|
| Intro / thesis ("from app to assistant") | 2 min |
| Beat 1 — simple ask | 1.5 min |
| Beat 2 — multi-step + calendar (the money shot) | 3 min |
| Beat 3 — memory follow-up | 2 min |
| Beat 4 — safety | 1.5 min |
| Beat 5 — generative plan finale | 3 min |
| Close / takeaways | 2 min |

The build should make the reasoning-trace pacing tunable so the presenter can speed up or slow down per beat during rehearsal.

---

## 7. What "done" looks like for the build

The demo is ready when, running on a single device with seeded data and no manual setup between beats, the presenter can:

1. Type each of the five user lines in sequence and watch the reasoning trace render legibly for each.
2. See a *generated, interactive* UI surface for every substantive beat (1, 2, 3, 5) and a calm explanatory surface for Beat 4.
3. Tap **Confirm** in Beat 2 and then show a **real calendar event** on the device.
4. Use only pronouns in Beat 3 and have Aria resolve them correctly, with the reminder updating in place.
5. Issue the Beat 4 deletion request and get a structural refusal with **nothing deleted**.
6. Reach Beat 5 and watch a multi-component interface compose itself from a single open-ended line.
7. Run the entire sequence twice and get **identical** visible results both times.

---

## 8. Open questions to resolve in ARCHITECTURE.md

These are deliberately left out of this storyline doc and must be settled in the technical companion:

- The exact two-stage pipeline: how the LangChain.dart `AgentExecutor` result is handed to a generative step that emits genui surface data.
- The genui widget **catalog** definition (which custom `CatalogItem`s exist: SpendingSummaryCard, ConfirmationCard, ReminderStatusCard, SavingsPlanCard, CapabilityInfoCard).
- The tool set and JSON schemas (`query_transactions`, `summarize_spending`, `set_budget_reminder`, `update_budget_reminder`) — and the deliberate *absence* of any delete tool.
- Memory implementation (`ConversationBufferMemory`, `returnMessages: true`) and what exactly persists between turns.
- Device API plugins (calendar, local DB) and the sandbox boundary.
- LLM provider choice and the rehearsed-safe deterministic fallback.
- The reasoning-trace rendering component and its pacing controls.
