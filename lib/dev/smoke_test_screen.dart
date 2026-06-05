// THROWAWAY SCAFFOLDING — build step 1 only.
//
// This screen exists solely to prove that Gemini responds through BOTH demo
// stages before any real feature work begins:
//   • Stage 1 (reasoning)  -> langchain_firebase `ChatFirebaseVertexAI`
//   • Stage 2 (rendering)  -> firebase_ai `FirebaseAI.vertexAI().generativeModel()`
// Both route through Firebase using the vertexAI backend, model
// `gemini-2.5-flash`, temperature 0. It will be deleted/replaced by the real
// chat screen in later build steps. Do not build features on top of it.

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:langchain/langchain.dart' show PromptValue;
import 'package:langchain_firebase/langchain_firebase.dart';

/// Result of a single stage's smoke call.
enum _Status { idle, running, pass, fail }

class _StageResult {
  const _StageResult(this.status, [this.detail = '']);
  final _Status status;
  final String detail;

  static const idle = _StageResult(_Status.idle);
}

class SmokeTestScreen extends StatefulWidget {
  const SmokeTestScreen({super.key});

  @override
  State<SmokeTestScreen> createState() => _SmokeTestScreenState();
}

class _SmokeTestScreenState extends State<SmokeTestScreen> {
  static const _model = 'gemini-2.5-flash';
  static const _prompt = 'Reply with exactly: pong';

  _StageResult _stage1 = _StageResult.idle;
  _StageResult _stage2 = _StageResult.idle;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Auto-run once on first frame so the smoke result is observable without a
    // manual tap (e.g. when driven headless). The button re-runs on demand.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSmokeTest());
  }

  Future<void> _runSmokeTest() async {
    setState(() {
      _running = true;
      _stage1 = const _StageResult(_Status.running);
      _stage2 = const _StageResult(_Status.running);
    });

    // Run both stages independently so one failure does not mask the other.
    final s1 = await _runStage1();
    if (mounted) setState(() => _stage1 = s1);
    debugPrint('SMOKE Stage 1 (langchain_firebase): '
        '${s1.status == _Status.pass ? "PASS" : "FAIL"} :: ${s1.detail}');

    final s2 = await _runStage2();
    if (mounted) setState(() => _stage2 = s2);
    debugPrint('SMOKE Stage 2 (firebase_ai): '
        '${s2.status == _Status.pass ? "PASS" : "FAIL"} :: ${s2.detail}');

    if (mounted) setState(() => _running = false);
  }

  /// Stage 1 — LangChain.dart agent LLM path (vertexAI backend by default).
  Future<_StageResult> _runStage1() async {
    try {
      final llm = ChatFirebaseVertexAI(
        defaultOptions: const ChatFirebaseVertexAIOptions(
          model: _model,
          temperature: 0,
        ),
      );
      final res = await llm.invoke(PromptValue.string(_prompt));
      final text = res.outputAsString.trim();
      if (text.isEmpty) {
        return const _StageResult(_Status.fail, 'Empty response');
      }
      return _StageResult(_Status.pass, text);
    } catch (e) {
      return _StageResult(_Status.fail, e.toString());
    }
  }

  /// Stage 2 — firebase_ai generative model path (rendering transport).
  Future<_StageResult> _runStage2() async {
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(temperature: 0),
      );
      final out = await model.generateContent([Content.text(_prompt)]);
      final text = (out.text ?? '').trim();
      if (text.isEmpty) {
        return const _StageResult(_Status.fail, 'Empty response');
      }
      return _StageResult(_Status.pass, text);
    } catch (e) {
      return _StageResult(_Status.fail, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aria — Gemini smoke test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirms Gemini responds through both demo stages via Firebase '
              '(vertexAI, $_model, temp 0).',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _StageTile(label: 'Stage 1 · langchain_firebase', result: _stage1),
            const SizedBox(height: 12),
            _StageTile(label: 'Stage 2 · firebase_ai', result: _stage2),
            const Spacer(),
            FilledButton.icon(
              onPressed: _running ? null : _runSmokeTest,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              label: Text(_running ? 'Running…' : 'Run smoke test'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.label, required this.result});

  final String label;
  final _StageResult result;

  ({IconData icon, Color color, String word}) get _badge =>
      switch (result.status) {
        _Status.idle => (icon: Icons.circle_outlined, color: Colors.grey, word: 'idle'),
        _Status.running => (icon: Icons.hourglass_top, color: Colors.amber, word: 'running'),
        _Status.pass => (icon: Icons.check_circle, color: Colors.greenAccent, word: 'PASS'),
        _Status.fail => (icon: Icons.error, color: Colors.redAccent, word: 'FAIL'),
      };

  @override
  Widget build(BuildContext context) {
    final b = _badge;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: b.color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(b.icon, color: b.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(b.word, style: TextStyle(color: b.color, fontWeight: FontWeight.bold)),
            ],
          ),
          if (result.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.detail,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
