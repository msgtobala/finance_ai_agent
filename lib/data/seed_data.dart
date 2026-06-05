// The fixed "Bengaluru" demo dataset (STORYLINE §3.5).
//
// These numbers are load-bearing for the talk: Beat 1 shows the ₹47,200 total
// and per-category breakdown with `food` as the obvious standout. Do NOT change
// any value here without updating STORYLINE §3.5 — determinism on stage depends
// on the on-screen totals being identical every run.

/// Canonical per-category totals (₹, whole rupees). Single source of truth,
/// reused by the repo and the test to assert the seed sums exactly.
const Map<String, int> kCategoryTotals = {
  'food': 14800, // deliberately dominant
  'bills': 13000,
  'shopping': 9500,
  'entertainment': 6800,
  'transport': 3100,
};

/// Sum of [kCategoryTotals] — the headline "last month" figure.
const int kGrandTotal = 47200;

/// One fixed seed line item. [dayOfMonth] (1–28, safe for any month) is placed
/// in the *previous calendar month* at seed time by the repo, so
/// `query('last_month')` always returns the full set after a reset.
class SeedTxn {
  const SeedTxn(this.category, this.merchant, this.amount, this.dayOfMonth);

  final String category;
  final String merchant;
  final int amount;
  final int dayOfMonth;
}

/// The fixed line items. Each category's amounts sum exactly to
/// [kCategoryTotals]; the per-line split is internal (never shown on screen —
/// Beat 1 renders category totals, not individual transactions).
const List<SeedTxn> kSeedTransactions = [
  // food → 14,800 (Swiggy / Zomato)
  SeedTxn('food', 'Swiggy', 3200, 3),
  SeedTxn('food', 'Zomato', 2800, 6),
  SeedTxn('food', 'Swiggy', 2400, 9),
  SeedTxn('food', 'Zomato', 2100, 14),
  SeedTxn('food', 'Swiggy', 1900, 19),
  SeedTxn('food', 'Zomato', 2400, 25),

  // bills → 13,000 (utilities)
  SeedTxn('bills', 'BESCOM Electricity', 4200, 2),
  SeedTxn('bills', 'ACT Broadband', 1499, 5),
  SeedTxn('bills', 'Airtel Mobile', 799, 8),
  SeedTxn('bills', 'Gas Cylinder', 1100, 11),
  SeedTxn('bills', 'BWSSB Water', 902, 15),
  SeedTxn('bills', 'Credit Card Bill', 4500, 28),

  // shopping → 9,500 (Myntra / Amazon)
  SeedTxn('shopping', 'Myntra', 2999, 7),
  SeedTxn('shopping', 'Amazon', 1850, 13),
  SeedTxn('shopping', 'Myntra', 1299, 20),
  SeedTxn('shopping', 'Amazon', 3352, 26),

  // entertainment → 6,800 (streaming / outings)
  SeedTxn('entertainment', 'Netflix', 649, 4),
  SeedTxn('entertainment', 'Spotify', 199, 10),
  SeedTxn('entertainment', 'BookMyShow', 1400, 16),
  SeedTxn('entertainment', 'Concert', 2100, 21),
  SeedTxn('entertainment', 'BookMyShow', 1252, 24),
  SeedTxn('entertainment', 'Prime Video', 1200, 27),

  // transport → 3,100 (Uber / Ola / fuel)
  SeedTxn('transport', 'Uber', 320, 1),
  SeedTxn('transport', 'Fuel', 1500, 12),
  SeedTxn('transport', 'Ola', 460, 17),
  SeedTxn('transport', 'Uber', 540, 22),
  SeedTxn('transport', 'Ola', 280, 23),
];
