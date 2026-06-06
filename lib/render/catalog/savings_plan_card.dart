// Beat 5's finale card (ARCHITECTURE §5.2/§5.3, STORYLINE Beat 5).
//
// The most elaborate, INTERACTIVE surface in the demo: a generated savings plan with
// per-category budget targets, each with an "accept this target" toggle, plus a single
// [Set these reminders] action. Tapping it dispatches a `set_savings_reminders` UI
// event carrying the accepted categories; the app's dispatch bridge turns that into a
// NEW user turn that re-enters Stage 1 (never Stage 2 directly, §5.3), which calls
// set_budget_reminder for each accepted category. The card never calls Stage 2 itself —
// it only emits an event. Built deterministically in mode 4A (no second model call);
// the targets come from `lib/render/outcome_to_surface.dart`.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Catalog item name used as the `component` discriminator in payloads.
const String kSavingsPlanCardName = 'SavingsPlanCard';

/// The action dispatched when [Set these reminders] is tapped. The bridge matches it.
const String kSetSavingsRemindersAction = 'set_savings_reminders';

final _schema = S.object(
  description:
      'A plan to spend less: per-category budget targets the user can accept, '
      'and a single action to turn the accepted ones into recurring reminders.',
  properties: {
    'headline': S.string(description: 'The plan headline.'),
    'recurrence': S.string(
      description: 'How often the resulting reminders recur.',
      enumValues: ['weekly', 'monthly'],
    ),
    'actionLabel': S.string(description: 'Label for the action button.'),
    'targets': S.list(
      description: 'Per-category suggested targets.',
      items: S.object(
        properties: {
          'category': S.string(),
          'current': S.number(),
          'target': S.number(),
          'saving': S.number(),
        },
        required: ['category', 'current', 'target', 'saving'],
      ),
    ),
  },
  required: ['headline', 'recurrence', 'targets'],
);

/// One suggested budget target, parsed from the payload.
class _Target {
  _Target({
    required this.category,
    required this.current,
    required this.target,
    required this.saving,
  });

  final String category;
  final num current;
  final num target;
  final num saving;
}

/// Formats an integer rupee amount as e.g. `₹14,800` (Indian digit grouping).
/// Mirrors the other cards' formatter — kept local so the card stays self-contained.
String _rupees(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  final int firstGroupEnd = digits.length > 3 ? digits.length - 3 : 0;
  for (int i = 0; i < digits.length; i++) {
    final int fromEnd = digits.length - i;
    final bool atGroupBoundary = i > 0 &&
        (i < firstGroupEnd ? (fromEnd - 3) % 2 == 0 : fromEnd == 3);
    if (atGroupBoundary) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '₹$buffer';
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// The Beat 5 interactive savings-plan card.
final CatalogItem savingsPlanCard = CatalogItem(
  name: kSavingsPlanCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final headline = (data['headline'] as String?) ?? 'Plan to spend less';
      final recurrence = (data['recurrence'] as String?) ?? 'monthly';
      final actionLabel =
          (data['actionLabel'] as String?) ?? 'Set these reminders';
      final targets = ((data['targets'] as List?) ?? const [])
          .whereType<Map<String, Object?>>()
          .map((t) => _Target(
                category: (t['category'] as String?) ?? '',
                current: (t['current'] as num?) ?? 0,
                target: (t['target'] as num?) ?? 0,
                saving: (t['saving'] as num?) ?? 0,
              ))
          .where((t) => t.category.isNotEmpty)
          .toList();

      return _SavingsPlanView(
        headline: headline,
        recurrence: recurrence,
        actionLabel: actionLabel,
        targets: targets,
        onSetReminders: (acceptedCategories) => itemContext.dispatchEvent(
          UserActionEvent(
            name: kSetSavingsRemindersAction,
            sourceComponentId: itemContext.id,
            context: {
              'categories': acceptedCategories.join(','),
              'recurrence': recurrence,
            },
          ),
        ),
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render savings plan.'),
        ),
      );
    }
  },
);

class _SavingsPlanView extends StatefulWidget {
  const _SavingsPlanView({
    required this.headline,
    required this.recurrence,
    required this.actionLabel,
    required this.targets,
    required this.onSetReminders,
  });

  final String headline;
  final String recurrence;
  final String actionLabel;
  final List<_Target> targets;
  final void Function(List<String> acceptedCategories) onSetReminders;

  @override
  State<_SavingsPlanView> createState() => _SavingsPlanViewState();
}

class _SavingsPlanViewState extends State<_SavingsPlanView> {
  // Which categories the user has accepted — all on by default.
  late final Map<String, bool> _accepted = {
    for (final t in widget.targets) t.category: true,
  };

  List<String> get _acceptedCategories =>
      widget.targets.map((t) => t.category).where((c) => _accepted[c] == true).toList();

  num get _totalSaving => widget.targets
      .where((t) => _accepted[t.category] == true)
      .fold<num>(0, (sum, t) => sum + t.saving);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final anyAccepted = _acceptedCategories.isNotEmpty;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, color: scheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.headline,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              anyAccepted
                  ? 'Save up to ${_rupees(_totalSaving)} / ${widget.recurrence == 'weekly' ? 'week' : 'month'}'
                  : 'Pick at least one target',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            for (final t in widget.targets) _targetRow(context, t),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: anyAccepted
                    ? () => widget.onSetReminders(_acceptedCategories)
                    : null,
                icon: const Icon(Icons.event_available),
                label: Text(widget.actionLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  textStyle: textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetRow(BuildContext context, _Target t) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final on = _accepted[t.category] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(t.category),
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_rupees(t.current)} → ${_rupees(t.target)}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: (value) =>
                setState(() => _accepted[t.category] = value),
          ),
        ],
      ),
    );
  }
}
