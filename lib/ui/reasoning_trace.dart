// The reasoning-trace panel — the hero visual (ARCHITECTURE §8, STORYLINE §3.1).
//
// Renders the streamed `TraceStep`s from `reasoningTraceProvider`: one line per
// step, large and high-contrast so it reads from the back of a room. Glyph by
// kind: 🧠 thinking (muted), 🔧 tool (monospace, compact `tool(args)`), ✅ done
// (accent). The streaming/pacing lives in the provider; this just renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_outcome.dart';
import 'providers.dart';

class ReasoningTrace extends ConsumerWidget {
  const ReasoningTrace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(reasoningTraceProvider);
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _TraceLine(step: step),
          ),
      ],
    );
  }
}

class _TraceLine extends StatelessWidget {
  const _TraceLine({required this.step});

  final TraceStep step;

  static const _glyph = {
    TraceStepKind.thinking: '🧠',
    TraceStepKind.tool: '🔧',
    TraceStepKind.done: '✅',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (TextStyle? style, Color color) = switch (step.kind) {
      TraceStepKind.thinking => (
          textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          scheme.onSurfaceVariant,
        ),
      TraceStepKind.tool => (
          textTheme.titleMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
          scheme.onSurface,
        ),
      TraceStepKind.done => (
          textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          scheme.primary,
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_glyph[step.kind]} ', style: textTheme.titleLarge),
        Expanded(
          child: Text(step.text, style: style?.copyWith(color: color)),
        ),
      ],
    );
  }
}
