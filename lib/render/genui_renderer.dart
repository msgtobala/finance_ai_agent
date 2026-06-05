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

  /// The surfaces currently showing, in display order — empty when there's
  /// nothing to render (e.g. a kind not yet mapped to a card). Usually one card,
  /// but Beat 3 stacks two (regenerated ReminderStatusCard + CategoryFigureCard).
  /// The screen listens to this and renders a Surface per id.
  final ValueNotifier<List<String>> activeSurfaceIds =
      ValueNotifier<List<String>>(const []);

  /// User turns produced by interactive cards (e.g. a ConfirmationCard's Confirm
  /// tap). The screen feeds these back through `agentService.runTurn`, so a card
  /// tap re-enters STAGE 1 as a new turn — never Stage 2 directly (§5.3).
  Stream<String> get confirmationTurns => controller.onSubmit
      .expand((message) => message.parts.uiInteractionParts)
      .map((part) => confirmTurnForInteraction(part.interaction))
      .where((turn) => turn != null)
      .cast<String>();

  int _counter = 0;
  // The ids of the surfaces currently in the controller, tracked independently of
  // the visibility notifier (which the screen may clear mid-turn) so teardown is
  // always correct.
  List<String> _liveSurfaceIds = const [];

  /// Render [outcome] as genui surface(s) (mode 4A). Tears down the previous
  /// surfaces first so only the latest beat's cards show. One component per
  /// surface; Beat 3 yields two, stacked in order.
  void render(AgentOutcome outcome) {
    try {
      _deleteLive();

      final components = surfaceComponentsFor(outcome);
      if (components.isEmpty) {
        activeSurfaceIds.value = const []; // unmapped kind → screen shows answerText
        return;
      }
      final ids = <String>[];
      for (final component in components) {
        final surfaceId = 'aria-surface-${_counter++}';
        controller
            .handleMessage(CreateSurface(surfaceId: surfaceId, catalogId: ariaCatalogId));
        controller.handleMessage(
            UpdateComponents(surfaceId: surfaceId, components: [component]));
        ids.add(surfaceId);
      }
      _liveSurfaceIds = ids;
      activeSurfaceIds.value = ids;
    } catch (error, stack) {
      debugPrint('GenUiRenderer.render failed: $error\n$stack');
      activeSurfaceIds.value = const [];
    }
  }

  /// Tear down the current surfaces and hide them (e.g. at the start of a new turn).
  void clear() {
    _deleteLive();
    activeSurfaceIds.value = const [];
  }

  void _deleteLive() {
    for (final id in _liveSurfaceIds) {
      controller.handleMessage(DeleteSurface(surfaceId: id));
    }
    _liveSurfaceIds = const [];
  }

  void dispose() {
    controller.dispose();
    activeSurfaceIds.dispose();
  }
}
