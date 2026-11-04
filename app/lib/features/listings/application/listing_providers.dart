import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/session.dart';
import '../../price_board/application/price_scope.dart';
import '../data/listing_repository.dart';
import '../domain/listing.dart';

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => FirebaseListingRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);

class ListingFilterNotifier extends Notifier<ListingFilter> {
  /// Starts from the place chosen in the header (null = whole province).
  @override
  ListingFilter build() => ListingFilter(municipality: ref.watch(priceScopeProvider));
  void set(ListingFilter f) => state = f;
}

final listingFilterProvider = NotifierProvider<ListingFilterNotifier, ListingFilter>(
  ListingFilterNotifier.new,
);

final activeListingsProvider = StreamProvider.family<List<Listing>, ListingFilter>(
  (ref, f) => ref.watch(listingRepositoryProvider).watchActive(f),
);

final myListingsProvider = StreamProvider<List<Listing>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is! SignedIn) return Stream.value(const []);
  return ref.watch(listingRepositoryProvider).watchMine(s.user.uid);
});

final listingProvider = StreamProvider.family<Listing?, String>(
  (ref, id) => ref.watch(listingRepositoryProvider).watchOne(id),
);

/// Owner actions. Expiry renewals always set a fresh 14-day window.
class ListingActions {
  ListingActions(this._ref);
  final Ref _ref;
  ListingRepository get _repo => _ref.read(listingRepositoryProvider);

  Future<void> markSold(String id) => _repo.update(id, {'status': 'sold'});
  Future<void> remove(String id) => _repo.update(id, {'status': 'removed'});
  Future<void> renew(String id) => _repo.update(id, {
    'status': 'active',
    'expiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: AppConfig.listingDays)),
    ),
  });
  Future<void> edit(String id, {required double quantity, required double askingPrice}) =>
      _repo.update(id, {'quantity': quantity, 'askingPrice': askingPrice});
}

final listingActionsProvider = Provider<ListingActions>(ListingActions.new);
