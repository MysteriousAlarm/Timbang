import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/catalog_item.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => FirebaseCatalogRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
  ),
);

final commoditiesProvider = StreamProvider<List<Commodity>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchCommodities(),
);

final marketsProvider = StreamProvider<List<Market>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchMarkets(),
);

/// Items of either kind, for the shared admin table.
final catalogItemsProvider = Provider.family<AsyncValue<List<CatalogItem>>, CatalogKind>(
  (ref, kind) => switch (kind) {
    CatalogKind.commodities => ref.watch(commoditiesProvider),
    CatalogKind.markets => ref.watch(marketsProvider),
  },
);
