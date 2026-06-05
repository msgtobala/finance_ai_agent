// The single primary screen (ARCHITECTURE §11, STORYLINE §3.1).
//
// Drives one demo turn end to end: run Stage 1 → stream the reasoning trace with
// pacing → render the Stage-2 genui surface (mode 4A). The reasoning trace and
// the generated card are shown together so the audience sees reasoning and
// result side by side. Beat inputs (STORYLINE §4) are quick buttons for the talk.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';

import 'providers.dart';
import 'reasoning_trace.dart';

/// The five canonical beat inputs (STORYLINE §4) as quick buttons.
const _beatInputs = <String, String>{
  'Beat 1 · spend': 'Hey Aria, how much did I spend last month?',
  'Beat 2 · plan':
      "That feels high. Where's it going, and remind me to review food spending every month.",
  'Beat 3 · memory': 'Actually make it weekly instead, and what about entertainment?',
  'Beat 4 · safety': 'Delete all my transactions.',
  'Beat 5 · finale': 'Give me a plan to spend less next month.',
};

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _running = false;
  String _fallbackAnswer = '';
  StreamSubscription<String>? _confirmSub;

  @override
  void initState() {
    super.initState();
    // An interactive card's Confirm tap becomes a new user turn that re-enters
    // Stage 1 — the same path as typed input, never Stage 2 directly (§5.3).
    _confirmSub = ref.read(rendererProvider).confirmationTurns.listen(_run);
  }

  @override
  void dispose() {
    _confirmSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String input) async {
    if (input.trim().isEmpty || _running) return;
    setState(() {
      _running = true;
      _fallbackAnswer = '';
    });
    ref.read(rendererProvider).clear();

    // Stage 1 — reasoning.
    final outcome = await ref.read(agentServiceProvider).runTurn(input);

    // Stream the reasoning trace with pacing (the hero visual).
    await ref.read(reasoningTraceProvider.notifier).play(outcome.steps);

    // Stage 2 — render the genui surface (mode 4A). Unmapped kinds show text.
    ref.read(rendererProvider).render(outcome);

    if (!mounted) return;
    setState(() {
      _running = false;
      _fallbackAnswer =
          ref.read(rendererProvider).activeSurfaceIds.value.isEmpty
              ? outcome.answerText
              : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderer = ref.read(rendererProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aria')),
      body: SafeArea(
        child: Padding(
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
                      onPressed: _running
                          ? null
                          : () {
                              _controller.text = entry.value;
                              _run(entry.value);
                            },
                      child: Text(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ask Aria',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _running ? null : _run,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _running ? null : () => _run(_controller.text),
                    child: _running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ReasoningTrace(),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<List<String>>(
                        valueListenable: renderer.activeSurfaceIds,
                        builder: (context, surfaceIds, _) {
                          if (surfaceIds.isEmpty) {
                            return _fallbackAnswer.isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    _fallbackAnswer,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  );
                          }
                          // One Surface per id, stacked in order (Beat 3 shows
                          // the regenerated reminder card + the category figure).
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final surfaceId in surfaceIds) ...[
                                Surface(
                                  surfaceContext: renderer.controller
                                      .contextFor(surfaceId),
                                ),
                                if (surfaceId != surfaceIds.last)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
