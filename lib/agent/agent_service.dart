import 'package:langchain/langchain.dart';
import 'package:langchain_firebase/langchain_firebase.dart';
import 'package:logging/logging.dart';

import '../data/calendar_service.dart';
import '../data/transaction_repo.dart';
import 'agent_outcome.dart';
import 'system_prompt_stage1.dart';
import 'tools/query_transactions.dart';
import 'tools/set_budget_reminder.dart';
import 'tools/summarize_spending.dart';
import 'tools/update_budget_reminder.dart';

/// The complete Stage-1 tool set — this list IS the sandbox boundary.
///
/// There is deliberately NO delete / wipe tool here, and nothing pattern-matches
/// "delete": Beat 4's refusal is structural (the model cannot delete because no
/// such capability is registered). Extracted as a top-level function so it can be
/// asserted in tests without standing up Firebase/the LLM.
List<Tool> buildAriaTools({
  required TransactionRepo repo,
  required CalendarService calendar,
}) {
  return <Tool>[
    buildQueryTransactionsTool(repo), // read-only
    buildSummarizeSpendingTool(), // pure compute
    buildSetBudgetReminderTool(calendar), // create reminder
    buildUpdateBudgetReminderTool(calendar), // update reminder
  ];
}

/// Stage 1 — agentic reasoning (LangChain.dart + Gemini via Firebase).
///
/// Builds the LLM, the tool set, memory, agent and executor ONCE and holds them,
/// so `ConversationBufferMemory` accumulates across turns (Beat 3 resolves "make
/// it weekly" against earlier context). Gemini is reached through Firebase
/// (vertexAI backend), temperature 0 for stage determinism.
class AgentService {
  AgentService({
    required TransactionRepo repo,
    required CalendarService calendar,
  }) {
    final llm = ChatFirebaseVertexAI(
      defaultOptions: const ChatFirebaseVertexAIOptions(
        model: 'gemini-2.5-flash',
        temperature: 0,
      ),
    );

    // The tool set IS the sandbox boundary. There is deliberately NO delete /
    // wipe tool, and nothing here pattern-matches "delete": Beat 4's refusal is
    // structural — the model cannot delete because no such capability exists.
    final tools = <Tool>[
      buildQueryTransactionsTool(repo), // read-only
      buildSummarizeSpendingTool(), // pure compute
      buildSetBudgetReminderTool(calendar), // create reminder
      buildUpdateBudgetReminderTool(calendar), // update reminder
    ];

    _memory = ConversationBufferMemory(returnMessages: true);

    final agent = ToolsAgent.fromLLMAndTools(
      llm: llm,
      tools: tools,
      memory: _memory,
      systemChatMessage:
          SystemChatMessagePromptTemplate.fromTemplate(kStage1SystemPrompt),
    );

    _executor = AgentExecutor(
      agent: agent,
      maxIterations: 6, // safety cap on the reasoning loop
      returnIntermediateSteps: true, // drives the reasoning-trace panel
    );
  }

  static final Logger _log = Logger('aria.agent.agentService');

  late final ConversationBufferMemory _memory;
  late final AgentExecutor _executor;

  /// Run one user turn through Stage 1 and return the structured [AgentOutcome]
  /// seam Stage 2 renders from (ARCHITECTURE.md §3.4). Never throws — on failure
  /// it returns a benign outcome (empty effects ⇒ `capabilityInfo`) so the demo
  /// can't hard-crash on stage.
  Future<AgentOutcome> runTurn(String input) async {
    try {
      final result = await _executor.invoke({'input': input});
      final steps =
          (result[AgentExecutor.intermediateStepsOutputKey] as List?)
                  ?.cast<AgentStep>() ??
              const <AgentStep>[];
      return buildAgentOutcome(
        userText: input,
        answerText: result['output'] as String? ?? '',
        steps: steps,
      );
    } catch (e, st) {
      _log.severe('runTurn failed for input: $input', e, st);
      return buildAgentOutcome(
        userText: input,
        answerText: 'Sorry — something went wrong while reasoning about that.',
        steps: const [],
      );
    }
  }

  /// Clear conversation memory (e.g. to restart the demo from Beat 1).
  Future<void> resetMemory() => _memory.clear();
}
