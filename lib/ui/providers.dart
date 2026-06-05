import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transaction_repo.dart';

/// DI hub (ARCHITECTURE §10). Stage-1 tools and the UI read shared services
/// from here. More providers (agent, renderer, reasoning trace, calendar,
/// demo mode) are added in later build steps.

/// The seeded transaction database. READ-ONLY to the agent: the future
/// `query_transactions` tool calls [TransactionRepo.query] only — never the
/// seed/reset write methods (CLAUDE.md sandbox boundary).
final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  final repo = TransactionRepo();
  ref.onDispose(repo.close);
  return repo;
});
