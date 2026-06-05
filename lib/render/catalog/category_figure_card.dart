// Beat 3's follow-up card (ARCHITECTURE §5.2, STORYLINE Beat 3).
//
// A small, self-contained genui `CatalogItem`: one category's spend for a period
// (e.g. entertainment ≈ ₹6,800 last month). It reads everything from its own data
// payload — no child component references — which keeps mode-4A rendering robust on
// stage. The payload is built deterministically in `lib/render/outcome_to_surface.dart`
// (no second model call). In Beat 3 it renders stacked under the regenerated
// ReminderStatusCard.

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The catalog item name used as the `component` discriminator in payloads.
const String kCategoryFigureCardName = 'CategoryFigureCard';

final _schema = S.object(
  description:
      'A single spending category figure for a period: the category, the amount '
      'spent, the period, and how many transactions made it up.',
  properties: {
    'category': S.string(description: 'The spending category, e.g. entertainment.'),
    'amount': S.number(description: 'The total spent in that category, in rupees.'),
    'period': S.string(description: 'The period in words, e.g. "last month".'),
    'count': S.number(description: 'How many transactions, if known.'),
  },
  required: ['category', 'amount'],
);

/// Formats an integer rupee amount as e.g. `₹6,800` (Indian digit grouping).
/// Mirrors `spending_summary_card._rupees` — kept local so each card stays
/// self-contained (ARCHITECTURE §10).
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

/// The Beat 3 category-figure card.
final CatalogItem categoryFigureCard = CatalogItem(
  name: kCategoryFigureCardName,
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    try {
      final data = itemContext.data as Map<String, Object?>;
      final category = (data['category'] as String?) ?? '';
      final amount = (data['amount'] as num?) ?? 0;
      final period = (data['period'] as String?) ?? '';
      final count = (data['count'] as num?)?.toInt();

      return _CategoryFigureView(
        category: category,
        amount: amount,
        period: period,
        count: count,
      );
    } catch (error, stack) {
      itemContext.reportError(error, stack);
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not render category figure.'),
        ),
      );
    }
  },
);

class _CategoryFigureView extends StatelessWidget {
  const _CategoryFigureView({
    required this.category,
    required this.amount,
    required this.period,
    required this.count,
  });

  final String category;
  final num amount;
  final String period;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitleParts = <String>[
      if (period.isNotEmpty) period,
      if (count != null) '$count transaction${count == 1 ? '' : 's'}',
    ];
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _capitalize(category),
              style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              _rupees(amount),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' · '),
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
