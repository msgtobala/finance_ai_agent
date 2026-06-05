// Stage 2 — genui rendering (ARCHITECTURE §5 / §7 `rendererProvider`).
//
// Owns a single genui `SurfaceController` bound to the Aria catalog and turns an
// `AgentOutcome` into a rendered surface via the mode-4A mapping. In 4A there is
// no model and no transport here — we feed hand-built A2UI messages straight to
// the controller, which validates them against the catalog schema. The bound
// `Surface` widget (built by the screen via `controller.contextFor(id)`) then
// rebuilds. Never throws: the demo must not hard-crash on stage.

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../agent/agent_outcome.dart';
import 'catalog/aria_catalog.dart';
import 'dispatch_bridge.dart';
import 'outcome_to_surface.dart';

class GenUiRenderer {
  GenUiRenderer() : controller = SurfaceController(catalogs: [ariaCatalog]);

  /// The genui runtime. The screen reads `controller.contextFor(surfaceId)` to
  /// build a `Surface`.
  final SurfaceController controller;

  /// The surface currently showing, or null when there's nothing to render
  /// (e.g. a kind not yet mapped to a card). The screen listens to this.
  final ValueNotifier<String?> activeSurfaceId = ValueNotifier<String?>(null);

  /// User turns produced by interactive cards (e.g. a ConfirmationCard's Confirm
  /// tap). The screen feeds these back through `agentService.runTurn`, so a card
  /// tap re-enters STAGE 1 as a new turn — never Stage 2 directly (§5.3).
  Stream<String> get confirmationTurns => controller.onSubmit
      .expand((message) => message.parts.uiInteractionParts)
      .map((part) => confirmTurnForInteraction(part.interaction))
      .where((turn) => turn != null)
      .cast<String>();

  int _counter = 0;
  // The id of the surface currently in the controller, tracked independently of
  // the visibility notifier (which the screen may null mid-turn) so teardown is
  // always correct.
  String? _liveSurfaceId;

  /// Render [outcome] as a genui surface (mode 4A). Tears down the previous
  /// surface first so only the latest beat's card shows.
  void render(AgentOutcome outcome) {
    try {
      _deleteLive();

      final surfaceId = 'aria-surface-${_counter++}';
      final messages = surfaceMessagesFor(outcome, surfaceId: surfaceId);
      if (messages.isEmpty) {
        activeSurfaceId.value = null; // unmapped kind → screen shows answerText
        return;
      }
      for (final message in messages) {
        controller.handleMessage(message);
      }
      _liveSurfaceId = surfaceId;
      activeSurfaceId.value = surfaceId;
    } catch (error, stack) {
      debugPrint('GenUiRenderer.render failed: $error\n$stack');
      activeSurfaceId.value = null;
    }
  }

  /// Tear down the current surface and hide it (e.g. at the start of a new turn).
  void clear() {
    _deleteLive();
    activeSurfaceId.value = null;
  }

  void _deleteLive() {
    final current = _liveSurfaceId;
    if (current != null) {
      controller.handleMessage(DeleteSurface(surfaceId: current));
      _liveSurfaceId = null;
    }
  }

  void dispose() {
    controller.dispose();
    activeSurfaceId.dispose();
  }
}
