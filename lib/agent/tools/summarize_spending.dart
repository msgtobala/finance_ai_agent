import 'dart:convert';

import 'package:langchain/langchain.dart';

/// Pure-compute tool: totals and groups a JSON transaction list by category.
/// No external dependencies and no side effects.
Tool buildSummarizeSpendingTool() {
  return Tool.fromFunction<Map<String, dynamic>, String>(
    name: 'summarize_spending',
    description:
        'Total and group a JSON transaction list (as returned by '
        'query_transactions) by category. Returns {byCategory, total, '
        'topCategory}. Pure compute.',
    inputJsonSchema: const {
      'type': 'object',
      'properties': {
        'transactions_json': {
          'type': 'string',
          'description': 'The JSON array returned by query_transactions.',
        },
      },
      'required': ['transactions_json'],
    },
    func: (input) async {
      try {
        final list = (jsonDecode(input['transactions_json'] as String) as List)
            .cast<Map<String, dynamic>>();
        final totals = <String, num>{};
        for (final t in list) {
          final category = t['category'] as String;
          totals[category] = (totals[category] ?? 0) + (t['amount'] as num);
        }
        final topCategory = totals.entries.isEmpty
            ? null
            : totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        return jsonEncode({
          'byCategory': totals,
          'total': totals.values.fold<num>(0, (a, b) => a + b),
          'topCategory': topCategory,
        });
      } catch (e) {
        return jsonEncode({'error': 'summarize_spending failed: $e'});
      }
    },
  );
}
