// Scripted Stage-1 runner (ARCHITECTURE §9). The deterministic path the talk runs
// on: for a matched canonical input it replays the fixture's reasoning trace + UI
// choice, but the TOOLS STILL REALLY RUN — so every device side effect (calendar
// writes) is genuine and the surfaces are built from real data by the same 4A
// mapping. Unmatched (off-script) input degrades gracefully to the live agent.
//
// This file owns NO model and NO genui: it runs real tools and assembles an
// AgentOutcome, exactly the seam the live AgentService produces.

import 'dart:convert';

import 'package:langchain/langchain.dart';
import 'package:logging/logging.dart';

import '../data/calendar_service.dart';
import '../data/transaction_repo.dart';
import '../demo/fixtures/fixture.dart';
import '../demo/fixtures/fixtures.dart';
import 'agent_outcome.dart';
import 'agent_service.dart';

class ScriptedAgentService implements AgentRunner {
  ScriptedAgentService({
    required this.live,
    required TransactionRepo repo,
    required CalendarService calendar,
  }) : _tools = {
          for (final tool in buildAriaTools(repo: repo, calendar: calendar))
            tool.name: tool,
        };

  /// The live agent — used as the graceful fallback for off-script input.
  final AgentRunner live;

  /// The real tools, by name. Same behavior as live: real DB reads / calendar
  /// writes, sharing the calendar service's per-category session state.
  final Map<String, Tool> _tools;

  static final Logger _log = Logger('aria.agent.scriptedAgentService');

  @override
  Future<AgentOutcome> runTurn(String input) async {
    final fixture = matchFixture(input);
    if (fixture == null) {
      // Off-script: keep the demo alive by handing the turn to the live model.
      _log.info('No fixture for "$input" — falling back to live mode.');
      return live.runTurn(input);
    }

    final effects = await _runToolCalls(fixture.toolCalls);
    return AgentOutcome(
      userText: input,
      answerText: fixture.answerText,
      steps: fixture.steps,
      effects: effects,
      kind: fixture.kind,
    );
  }

  /// Execute the fixture's tool calls for real, in order, building a [ToolEffect]
  /// per call (same shape live mode lifts from `intermediateSteps`). The
  /// `summarize_spending` call is fed the most recent `query_transactions` result
  /// as its `transactions_json`, mirroring how the live agent chains them.
  Future<List<ToolEffect>> _runToolCalls(List<ScriptedToolCall> calls) async {
    final effects = <ToolEffect>[];
    String? lastQueryResult;

    for (final call in calls) {
      final args = Map<String, dynamic>.from(call.args);
      if (call.tool == 'summarize_spending' && lastQueryResult != null) {
        args['transactions_json'] = lastQueryResult;
      }

      String result;
      try {
        final tool = _tools[call.tool];
        if (tool == null) {
          result = jsonEncode({'error': 'unknown tool: ${call.tool}'});
        } else {
          // Our tools are Tool.fromFunction<…, String>; invoke returns that
          // String. toString() is identity on a String and keeps the raw Tool's
          // erased Output type from leaking through.
          result = (await tool.invoke(args)).toString();
        }
      } catch (e, st) {
        _log.warning('scripted tool ${call.tool} failed', e, st);
        result = jsonEncode({'error': '${call.tool} failed: $e'});
      }

      if (call.tool == 'query_transactions') lastQueryResult = result;
      effects.add(_effectFrom(call.tool, args, result));
    }

    return effects;
  }

  /// Build a [ToolEffect] from a raw tool result string, exactly like
  /// `ToolEffect.fromStep` does for live `AgentStep`s.
  ToolEffect _effectFrom(String tool, Map<String, dynamic> input, String result) {
    Object? data;
    try {
      data = jsonDecode(result);
    } catch (_) {
      data = null;
    }
    final isError = data is Map && data.containsKey('error');
    return ToolEffect(tool: tool, input: input, data: data, isError: isError);
  }

  @override
  Future<void> resetMemory() => live.resetMemory();
}
