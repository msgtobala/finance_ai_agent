// Aria's genui catalog (ARCHITECTURE §5.2).
//
// Built on genui's `BasicCatalogItems` (the installed 0.9.2 name; NOT
// `CoreCatalogItems`) plus our custom cards. Steps 6–7 add the Beat 1
// `spendingSummaryCard` and the Beat 2 `confirmationCard` + `reminderStatusCard`;
// step 9 adds the Beat 3 `categoryFigureCard`; step 10 adds the Beat 4
// `capabilityInfoCard`; step 11 adds the Beat 5 `savingsPlanCard`. The full
// catalog (ARCHITECTURE §5.2) is now present.

import 'package:genui/genui.dart';

import 'capability_info_card.dart';
import 'category_figure_card.dart';
import 'confirmation_card.dart';
import 'reminder_status_card.dart';
import 'savings_plan_card.dart';
import 'spending_summary_card.dart';

/// Catalog id shared by the catalog and every `CreateSurface` payload — they
/// must match for a surface to resolve its catalog.
const String ariaCatalogId = 'com.aria.catalog';

/// The catalog of widgets Stage 2 can render.
final Catalog ariaCatalog = BasicCatalogItems.asCatalog().copyWith(
  catalogId: ariaCatalogId,
  newItems: [
    spendingSummaryCard,
    confirmationCard,
    reminderStatusCard,
    categoryFigureCard,
    capabilityInfoCard,
    savingsPlanCard,
  ],
);
