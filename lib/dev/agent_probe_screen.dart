// THROWAWAY dev harness — build step 4 only.
//
// Lets you run one Stage-1 turn and watch the agent reason. The final answer and
// every intermediate step are printed to the console (visible in `flutter run`
// logs on the emulator) and echoed compactly on screen. The real chat UI +
// reasoning-trace panel + genui cards arrive in later steps; do not build on this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_outcome.dart';
import '../ui/providers.dart';

/// The five canonical beat inputs (STORYLINE §4) as quick buttons.
const _beatInputs = <String, String>{
  'Beat 1 · spend': 'Hey Aria, how much did I spend last month?',
  'Beat 2 · plan':
      "That feels high. Where's it going, and remind me to review food spending every month.",
  'Beat 3 · memory': 'Actually make it weekly instead, and what about entertainment?',
  'Beat 4 · safety': 'Delete all my transactions.',
  'Beat 5 · finale': 'Give me a plan to spend less next month.',
};

class AgentProbeScreen extends ConsumerStatefulWidget {
  const AgentProbeScreen({super.key});

  @override
  ConsumerState<AgentProbeScreen> createState() => _AgentProbeScreenState();
}

class _AgentProbeScreenState extends ConsumerState<AgentProbeScreen> {
  final _controller = TextEditingController();
  bool _running = false;
  AgentOutcome? _outcome;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String input) async {
    if (input.trim().isEmpty || _running) return;
    setState(() {
      _running = true;
      _outcome = null;
    });
    debugPrint('──────── AGENT TURN ────────');
    debugPrint('INPUT: $input');

    final outcome = await ref.read(agentServiceProvider).runTurn(input);

    for (final e in outcome.effects) {
      debugPrint('🔧 ${e.tool} ${e.input} -> ${e.isError ? '⚠️ ${e.data}' : e.data}');
    }
    debugPrint('🏷️ kind: ${outcome.kind.name}');
    debugPrint('✅ ${outcome.answerText}');
    debugPrint('──────── END TURN (${outcome.effects.length} effects) ────────');

    if (!mounted) return;
    setState(() {
      _running = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aria — Stage 1 agent probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _beatInputs.entries)
                  OutlinedButton(
                    onPressed: _running ? null : () {
                      _controller.text = entry.value;
                      _run(entry.value);
                    },
                    child: Text(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'User turn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _running ? null : () => _run(_controller.text),
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_running ? 'Reasoning…' : 'Run turn'),
            ),
            const SizedBox(height: 16),
            const Text('Reasoning trace + derived kind (also printed to console):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _OutcomeView(outcome: _outcome)),
          ],
        ),
      ),
    );
  }
}

/// Compact, throwaway view of one [AgentOutcome]: the derived kind chip, the
/// trace lines, and the final answer. The real trace panel + genui cards arrive
/// in steps 6–7; this just proves the seam per beat.
class _OutcomeView extends StatelessWidget {
  const _OutcomeView({required this.outcome});

  final AgentOutcome? outcome;

  static const _glyph = {
    TraceStepKind.thinking: '🧠',
    TraceStepKind.tool: '🔧',
    TraceStepKind.done: '✅',
  };

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    if (o == null) return const SizedBox.shrink();
    return ListView(
      children: [
        Chip(label: Text('kind: ${o.kind.name}')),
        const SizedBox(height: 8),
        for (final s in o.steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${_glyph[s.kind]} ${s.text}',
              style: s.kind == TraceStepKind.done
                  ? const TextStyle(fontSize: 16)
                  : const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }
}
