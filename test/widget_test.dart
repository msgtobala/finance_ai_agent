// Smoke widget test for build step 1.
//
// This only verifies the app shell builds and the smoke-test screen renders its
// Run button. The actual two-stage Gemini calls are device-only (Firebase needs
// platform channels + network) and cannot run under `flutter test`.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_assistant/main.dart';

void main() {
  testWidgets('Smoke test screen renders its Run button', (tester) async {
    await tester.pumpWidget(const AriaSmokeApp());

    expect(find.text('Run smoke test'), findsOneWidget);
    expect(find.text('Stage 1 · langchain_firebase'), findsOneWidget);
    expect(find.text('Stage 2 · firebase_ai'), findsOneWidget);
  });
}
