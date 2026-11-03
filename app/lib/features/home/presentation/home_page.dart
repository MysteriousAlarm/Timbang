import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/sections.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../price_board/presentation/price_board_section.dart';

/// Home: greeting, my town, quick actions, today's prices.
/// The live price board replaces the empty panel in Step 4.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
    final firstName = session.profile.name.trim().split(RegExp(r'\s+')).first;
    final isFarmer = session.role == Role.farmer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SharedTokens.space4,
        SharedTokens.space5,
        SharedTokens.space4,
        SharedTokens.space6,
      ),
      children: [
        Text(today.toUpperCase(), style: t.labelSmall),
        const SizedBox(height: SharedTokens.space1),
        Text(l10n.greeting(firstName), style: t.headlineSmall),
        const SizedBox(height: SharedTokens.space4),
        PanelCard(
          accent: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.primaryTint, shape: BoxShape.circle),
                child: Icon(Icons.location_on, color: scheme.primary),
              ),
              const SizedBox(width: SharedTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.myTown.toUpperCase(), style: t.labelSmall),
                    Text('${session.profile.municipality}, Nueva Vizcaya', style: t.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SharedTokens.space5),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SharedTokens.space3,
          crossAxisSpacing: SharedTokens.space3,
          childAspectRatio: 1.45,
          children: [
            _ActionTile(
              icon: isFarmer ? Icons.add_business_outlined : Icons.search,
              label: isFarmer ? l10n.actionPostProduce : l10n.actionFindProduce,
              cta: true,
              onTap: () => isFarmer ? context.push(Routes.newListing) : context.go(Routes.listings),
            ),
            _ActionTile(
              icon: Icons.compare_arrows,
              label: l10n.actionCompareMarkets,
              onTap: () => _pickCommodity(context, ref),
            ),
            _ActionTile(
              icon: Icons.notifications_active_outlined,
              label: l10n.actionPriceAlerts,
              onTap: () => context.go(Routes.alerts),
            ),
            _ActionTile(
              key: const Key('tileReport'),
              icon: Icons.edit_note,
              label: l10n.actionReportPrice,
              onTap: () => context.push(Routes.report),
            ),
          ],
        ),
        const SizedBox(height: SharedTokens.space6),
        const PriceBoardSection(),
      ],
    );
  }
}

/// "Ihambing ang palengke": choose a commodity, then open its market comparison.
Future<void> _pickCommodity(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final items = (ref.read(commoditiesProvider).value ?? const <Commodity>[])
      .where((c) => c.active)
      .toList();
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.chooseCommodity, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final c in items)
              ListTile(
                leading: const Icon(Icons.eco_outlined),
                title: Text(c.nameFil),
                subtitle: Text(c.nameEn),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (id != null && context.mounted) await context.push(Routes.commodity(id));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.cta = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The ONE cta-colored action on the screen.
  final bool cta;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fill = cta ? c.cta : scheme.surface;
    final fg = cta ? c.onCta : scheme.onSurface;
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        side: cta ? BorderSide.none : BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SharedTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 30, color: cta ? fg : scheme.primary),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
