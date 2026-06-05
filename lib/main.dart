import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'data/calendar_service.dart';
import 'firebase_options.dart';
import 'ui/chat_screen.dart';

final _log = Logger('aria.main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Boot Firebase. Both demo stages (Stage 1 reasoning via langchain_firebase
  // and Stage 2 rendering transport via firebase_ai) route through this app, so
  // it must succeed before the UI runs. Per CLAUDE.md the demo must never
  // hard-crash on stage: log and continue so the smoke screen can report it.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    _log.severe('Firebase.initializeApp failed', e, st);
  }

  // Prompt for calendar permission ONCE at launch so the presenter can grant it
  // before the talk — never mid-Beat-2 (ARCHITECTURE §13 "permission
  // pre-granted"). Best-effort: logged, never blocks the UI from running.
  unawaited(
    DeviceCalendarService().ensurePermissions().then((granted) {
      if (!granted) _log.warning('Calendar permission not granted at launch');
    }).catchError((Object e, StackTrace st) {
      _log.warning('Calendar permission prompt failed', e, st);
    }),
  );

  runApp(const ProviderScope(child: AriaSmokeApp()));
}

/// Minimal app shell for build step 1. The real chat screen replaces this in
/// later steps; for now it only hosts the two-stage Gemini smoke test.
class AriaSmokeApp extends StatelessWidget {
  const AriaSmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
