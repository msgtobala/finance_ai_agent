// Beat 4's safety card (ARCHITECTURE §5.2, STORYLINE Beat 4).
//
// A calm, non-interactive `CatalogItem`: when the user asks for something Aria has
// no tool for (e.g. "delete all my transactions"), Stage 1 runs NO tool, the
// AgentOutcome has empty effects, and `deriveOutcomeKind` routes to `capabilityInfo`.
// This card states plainly what Aria CAN do and that the request is outside its
// capabilities. The refusal is STRUCTURAL (no delete tool exists; the empty-effect
// routing is the mechanism) — this card only DISPLAYS it. It is matter-of-fact, not
// an error or an alarm (no red, no scary iconography). It reads everything from its
// own self-contained payload, built deterministically in
// `lib/render/outcome_to_surface.dart` — no second model call.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The catalog item name used as the `component` discriminator in payloads.
const String kCapabilityInfoCardName = 'CapabilityInfoCard';

final _schema = S.object(
  description:
      'A calm explanation of what the assistant can do, shown when the user asks '
      'for something it has no tool for. States capabilities plainly, not as an '
      'error.',
  properties: {
    'headline': S.string(description: 'A short, calm headline.'),
    'capabilities': S.list(
      description: 'What the assistant can actually do, one item per line.',
      items: S.string(),
    ),
    'limitation': S.string(
      description: 'A plain statement of what it cannot do and why.',
    ),
  },
  required: ['headline', 'capabilities'],
);

/// The Beat 4 capability-info card.
final CatalogItem capabilityInfoCard = CatalogItem(
  name: kCapabilityInfoCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final headline = (data['headline'] as String?) ?? 'Here\'s what I can do';
      final capabilities = ((data['capabilities'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      final limitation = data['limitation'] as String?;

      return _CapabilityInfoView(
        headline: headline,
        capabilities: capabilities,
        limitation: limitation,
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render capability info.'),
        ),
      );
    }
  },
);

class _CapabilityInfoView extends StatelessWidget {
  const _CapabilityInfoView({
    required this.headline,
    required this.capabilities,
    required this.limitation,
  });

  final String headline;
  final List<String> capabilities;
  final String? limitation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      // Normal surface — deliberately NOT an error color. This is calm, not alarm.
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: scheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    headline,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (capabilities.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final capability in capabilities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: scheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          capability,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (limitation != null && limitation!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                limitation!,
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
