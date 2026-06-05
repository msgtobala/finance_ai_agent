// Smoke widget test for the app shell. Verifies the agent-probe screen (the
// current dev home) renders its controls. No agent turn runs on build, so this
// needs no Firebase — the Gemini path is exercised on-device.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_assistant/main.dart';

void main() {
  testWidgets('Agent probe screen renders its controls', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AriaSmokeApp()));

    expect(find.text('Run turn'), findsOneWidget);
    expect(find.text('Beat 1 · spend'), findsOneWidget);
    expect(find.text('Beat 4 · safety'), findsOneWidget);
  });
}
