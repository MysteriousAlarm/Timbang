import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/confidence_chip.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../../price_board/application/board_providers.dart';
import '../../price_board/domain/board_entry.dart';
import '../../profile/presentation/municipality_field.dart';
import '../../reports/domain/price_report.dart';
import '../application/listing_providers.dart';
import '../data/listing_repository.dart';
import '../domain/listing.dart';

/// "Mag-post ng ani". Works offline (photos upload only with a connection).
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  String? _commodityId;
  String? _municipality;
  DateTime? _harvest = DateTime.now();
  final _photos = <Uint8List>[];
  List<DraftIssue> _issues = const [];
  bool _saving = false;
  String? _photoError;
  bool _townTouched = false;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final l10n = AppLocalizations.of(context);
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: AppConfig.listingPhotoMaxSide,
      maxHeight: AppConfig.listingPhotoMaxSide,
      imageQuality: AppConfig.listingPhotoQuality,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (bytes.length >= AppConfig.listingMaxPhotoBytes) {
        _photoError = l10n.photoTooLarge;
      } else {
        _photoError = null;
        _photos.add(bytes);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _harvest ?? now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _harvest = d);
  }

  Future<void> _submit(Commodity? commodity) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    if (session is! SignedIn) return;
    final draft = ListingDraft(
      commodityId: _commodityId,
      quantity: parseQuantity(_qty.text),
      unit: commodity?.unit ?? 'kg',
      askingPrice: parsePrice(_price.text),
      municipality: _municipality,
      harvestDate: _harvest,
      note: _note.text,
    );
    final issues = validateDraft(draft);
    setState(() => _issues = issues);
    if (issues.isNotEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(listingRepositoryProvider)
          .create(
            uid: session.user.uid,
            farmerName: session.profile.name,
            farmerPhone: session.profile.phone,
            draft: draft,
            photos: _photos,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            PostResult.saved => l10n.listingPosted,
            PostResult.queuedOffline => l10n.listingQueued,
            PostResult.photosFailed => l10n.listingPhotosFailed,
          }),
        ),
      );
      if (mounted) context.go(Routes.listings);
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  String? _err(DraftIssue i, String msg) => _issues.contains(i) ? msg : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final commodities = (ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        .where((x) => x.active)
        .toList();
    Commodity? commodity;
    for (final x in commodities) {
      if (x.id == _commodityId) commodity = x;
    }
    final unit = commodity == null ? '' : unitShort(l10n, commodity.unit);
    // Default to the farmer's own town once the profile is available.
    final session = ref.watch(sessionProvider);
    if (_municipality == null && !_townTouched && session is SignedIn) {
      _municipality = session.profile.municipality;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.listings),
        ),
        title: Text(l10n.actionPostProduce),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child:
              ref.watch(sessionProvider) is SignedIn &&
                  (ref.watch(sessionProvider) as SignedIn).role != Role.farmer
              ? MessageView(
                  icon: Icons.agriculture,
                  title: l10n.farmersOnlyTitle,
                  body: l10n.farmersOnlyBody,
                )
              : commodities.isEmpty
              ? MessageView(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.catalogEmptyTitle,
                  body:
                      (ref.watch(sessionProvider) is SignedIn &&
                          (ref.watch(sessionProvider) as SignedIn).isAdmin)
                      ? l10n.catalogEmptyAdmin
                      : l10n.reportNoCatalog,
                  action:
                      (ref.watch(sessionProvider) is SignedIn &&
                          (ref.watch(sessionProvider) as SignedIn).isAdmin)
                      ? FilledButton.icon(
                          onPressed: () => context.go(Routes.adminCommodities),
                          icon: const Icon(Icons.eco_outlined),
                          label: Text(l10n.catalogEmptyAdminButton),
                        )
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.all(SharedTokens.space4),
                  children: [
                    SectionHeader(kicker: l10n.newListingKicker, title: l10n.newListingTitle),
                    const SizedBox(height: SharedTokens.space2),
                    Text(l10n.newListingHelp, style: t.bodySmall),
                    const SizedBox(height: SharedTokens.space4),
                    DropdownButtonFormField<String>(
                      key: const Key('listingCommodity'),
                      initialValue: _commodityId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.fieldCommodity,
                        prefixIcon: const Icon(Icons.eco_outlined),
                        errorText: _err(DraftIssue.commodity, l10n.reportErrPick),
                      ),
                      items: [
                        for (final x in commodities)
                          DropdownMenuItem(value: x.id, child: Text(x.labelIn(context))),
                      ],
                      onChanged: (v) => setState(() => _commodityId = v),
                    ),
                    if (_commodityId != null) ...[
                      const SizedBox(height: SharedTokens.space3),
                      _MedianHint(commodityId: _commodityId!, municipality: _municipality),
                    ],
                    const SizedBox(height: SharedTokens.space4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('listingQty'),
                            controller: _qty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: InputDecoration(
                              labelText: l10n.fieldQuantity,
                              suffixText: unit,
                              errorText: _err(DraftIssue.quantity, l10n.errQuantity),
                            ),
                          ),
                        ),
                        const SizedBox(width: SharedTokens.space3),
                        Expanded(
                          child: TextField(
                            key: const Key('listingPrice'),
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: InputDecoration(
                              labelText: l10n.fieldAskingPrice,
                              prefixText: '₱ ',
                              suffixText: unit.isEmpty ? null : '/$unit',
                              errorText: _err(DraftIssue.price, l10n.reportErrInvalid),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SharedTokens.space4),
                    MunicipalityField(
                      // Rebuild when the default town arrives after the profile loads.
                      key: ValueKey(_municipality),
                      value: _municipality,
                      onChanged: (v) => setState(() {
                        _townTouched = true;
                        _municipality = v;
                      }),
                    ),
                    const SizedBox(height: SharedTokens.space4),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(SharedTokens.radius),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.fieldHarvestDate,
                          prefixIcon: const Icon(Icons.agriculture),
                          errorText: _err(DraftIssue.harvestDate, l10n.errHarvestDate),
                        ),
                        child: Text(
                          _harvest == null ? '' : DateFormat.yMMMMd(locale).format(_harvest!),
                          style: t.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: SharedTokens.space4),
                    TextField(
                      controller: _note,
                      maxLength: AppConfig.listingNoteMax,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.fieldNoteOptional,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: SharedTokens.space3),
                    Text(l10n.photosLabel(AppConfig.listingMaxPhotos), style: t.labelSmall),
                    const SizedBox(height: SharedTokens.space2),
                    Wrap(
                      spacing: SharedTokens.space2,
                      runSpacing: SharedTokens.space2,
                      children: [
                        for (var i = 0; i < _photos.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(SharedTokens.radius),
                                child: Image.memory(
                                  _photos[i],
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton.filled(
                                  tooltip: l10n.delete,
                                  onPressed: () => setState(() => _photos.removeAt(i)),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                        if (_photos.length < AppConfig.listingMaxPhotos)
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: OutlinedButton(
                              onPressed: _addPhoto,
                              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                              child: const Icon(Icons.add_a_photo_outlined),
                            ),
                          ),
                      ],
                    ),
                    if (_photoError != null) ...[
                      const SizedBox(height: SharedTokens.space2),
                      Text(
                        _photoError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: SharedTokens.space2),
                    Text(l10n.photosHelp, style: t.bodySmall),
                    const SizedBox(height: SharedTokens.space5),
                    CtaButton(
                      key: const Key('submitListing'),
                      label: l10n.postListing,
                      icon: Icons.storefront,
                      loading: _saving,
                      onPressed: () => _submit(commodity),
                    ),
                    const SizedBox(height: SharedTokens.space3),
                    Text(
                      l10n.listingExpiryNote(AppConfig.listingDays),
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shows today's median for this commodity near the farmer before they set a price.
class _MedianHint extends ConsumerWidget {
  const _MedianHint({required this.commodityId, required this.municipality});
  final String commodityId;
  final String? municipality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final board = ref.watch(commodityBoardProvider(commodityId)).value;
    final rows = compareRows(
      board?.entries ?? const [],
      ref.watch(orderedMarketsProvider),
      municipality,
    );
    if (rows.isEmpty) {
      return NoticeBanner(
        icon: Icons.info_outline,
        kind: NoticeKind.info,
        message: l10n.noMedianYet,
      );
    }
    final BoardEntry e = rows.first.entry;
    return PanelCard(
      accent: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.medianAt(rows.first.market.name), style: t.labelSmall),
                Text(
                  '${peso(e.medianPrice)} ${l10n.perUnit(unitShort(l10n, e.unit))}',
                  style: t.titleMedium,
                ),
                Text(l10n.knowBeforeSell, style: t.bodySmall),
              ],
            ),
          ),
          ConfidenceChip(confidence: e.confidence),
        ],
      ),
    );
  }
}
