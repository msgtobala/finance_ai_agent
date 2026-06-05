import 'dart:convert';

import 'package:langchain/langchain.dart';

import '../../data/transaction_repo.dart';

/// READ-ONLY tool: reads the user's transactions for a period and optional
/// category from the seeded DB. This is the agent's only window onto the data —
/// there is no write/delete counterpart, by design (STORYLINE Beat 4).
Tool buildQueryTransactionsTool(TransactionRepo repo) {
  return Tool.fromFunction<Map<String, dynamic>, String>(
    name: 'query_transactions',
    description:
        "Read the user's transactions for a period and optional category. "
        'Returns a JSON list of {amount, category, date, merchant}. READ ONLY.',
    inputJsonSchema: const {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': ['last_month', 'this_week', 'this_month'],
        },
        'category': {'type': 'string'},
      },
      'required': ['period'],
    },
    func: (input) async {
      try {
        final rows = await repo.query(
          period: input['period'] as String,
          category: input['category'] as String?,
        );
        return jsonEncode(rows);
      } catch (e) {
        return jsonEncode({'error': 'query_transactions failed: $e'});
      }
    },
  );
}
