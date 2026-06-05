// THROWAWAY dev harness — build step 4 only.
//
// Lets you run one Stage-1 turn and watch the agent reason. The final answer and
// every intermediate step are printed to the console (visible in `flutter run`
// logs on the emulator) and echoed compactly on screen. The real chat UI +
// reasoning-trace panel + genui cards arrive in later steps; do not build on this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart' show AgentStep;

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
  String _output = '';
  List<AgentStep> _steps = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String input) async {
    if (input.trim().isEmpty || _running) return;
    setState(() {
      _running = true;
      _output = '';
      _steps = const [];
    });
    debugPrint('──────── AGENT TURN ────────');
    debugPrint('INPUT: $input');

    final result = await ref.read(agentServiceProvider).runTurn(input);

    for (final s in result.steps) {
      debugPrint('🔧 ${s.action.tool} ${s.action.toolInput} -> ${s.observation}');
    }
    debugPrint('OUTPUT: ${result.output}');
    debugPrint('──────── END TURN (${result.steps.length} steps) ────────');

    if (!mounted) return;
    setState(() {
      _running = false;
      _output = result.output;
      _steps = result.steps;
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
            const Text('Reasoning trace (also printed to console):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final s in _steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '🔧 ${s.action.tool}  ${s.action.toolInput}\n   → ${s.observation}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  if (_output.isNotEmpty) ...[
                    const Divider(),
                    Text('✅ $_output', style: const TextStyle(fontSize: 16)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
