// Beat 1's catalog card (ARCHITECTURE §5.2, STORYLINE Beat 1).
//
// A self-contained genui `CatalogItem`: the headline total plus one bar per
// category, sorted so the dominant category (food) clearly stands out. It reads
// everything from its own data payload (no child component references), which
// keeps mode-4A rendering robust on stage. The payload is built deterministically
// in `lib/render/outcome_to_surface.dart` — no second model call.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The catalog item name used as the `component` discriminator in payloads.
const String kSpendingSummaryCardName = 'SpendingSummaryCard';

final _schema = S.object(
  description:
      'A summary of spending for a period: a headline total and a per-category '
      'breakdown, with the top category highlighted.',
  properties: {
    'total': S.number(description: 'The grand total spent, in rupees.'),
    'topCategory': S.string(description: 'The highest-spending category.'),
    'categories': S.list(
      description: 'Per-category spend, typically sorted highest-first.',
      items: S.object(
        properties: {
          'label': S.string(),
          'amount': S.number(),
        },
        required: ['label', 'amount'],
      ),
    ),
  },
  required: ['total', 'topCategory', 'categories'],
);

/// Formats an integer rupee amount as e.g. `₹14,800` (Indian digit grouping).
String _rupees(num value) {
  final digits = value.round().abs().toString();
  // Indian grouping: last 3 digits, then groups of 2.
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

/// The Beat 1 spending-summary card.
final CatalogItem spendingSummaryCard = CatalogItem(
  name: kSpendingSummaryCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final num total = (data['total'] as num?) ?? 0;
      final String topCategory = (data['topCategory'] as String?) ?? '';
      final categories = ((data['categories'] as List?) ?? const [])
          .whereType<Map<String, Object?>>()
          .map((c) => (
                label: (c['label'] as String?) ?? '',
                amount: (c['amount'] as num?) ?? 0,
              ))
          .toList();
      final num maxAmount = categories.isEmpty
          ? 1
          : categories.map((c) => c.amount).reduce((a, b) => a > b ? a : b);

      return _SpendingSummaryView(
        total: total,
        topCategory: topCategory,
        categories: categories,
        maxAmount: maxAmount == 0 ? 1 : maxAmount,
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render spending summary.'),
        ),
      );
    }
  },
);

class _SpendingSummaryView extends StatelessWidget {
  const _SpendingSummaryView({
    required this.total,
    required this.topCategory,
    required this.categories,
    required this.maxAmount,
  });

  final num total;
  final String topCategory;
  final List<({String label, num amount})> categories;
  final num maxAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Last month', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _rupees(total),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 20),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _CategoryBar(
                  label: c.label,
                  amount: c.amount,
                  fraction: (c.amount / maxAmount).clamp(0.0, 1.0).toDouble(),
                  highlight: c.label == topCategory,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.highlight,
  });

  final String label;
  final num amount;
  final double fraction;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = highlight ? scheme.primary : scheme.primary.withValues(alpha: 0.35);
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          color: scheme.onSurface,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_capitalize(label), style: labelStyle),
            Text(_rupees(amount), style: labelStyle),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 14,
            backgroundColor: scheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
