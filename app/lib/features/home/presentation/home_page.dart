import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../../price_board/presentation/price_board_section.dart';

/// Home: greeting and town, the one main action, three tools, then today's price bulletin.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
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
        Text(today, style: t.bodySmall),
        const SizedBox(height: 2),
        Text(l10n.greeting(firstName), style: t.headlineSmall),
        const SizedBox(height: SharedTokens.space1),
        Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: c.textMuted),
            const SizedBox(width: SharedTokens.space1),
            Expanded(
              child: Semantics(
                label: '${l10n.myTown}: ${session.profile.municipality}',
                excludeSemantics: true,
                child: Text('${session.profile.municipality}, Nueva Vizcaya', style: t.bodyMedium),
              ),
            ),
          ],
        ),
        const SizedBox(height: SharedTokens.space5),
        FilledButton.icon(
          key: const Key('primaryAction'),
          style: FilledButton.styleFrom(
            backgroundColor: c.cta,
            foregroundColor: c.onCta,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => isFarmer ? context.push(Routes.newListing) : context.go(Routes.listings),
          icon: Icon(isFarmer ? Icons.add_business_outlined : Icons.search),
          label: Text(isFarmer ? l10n.actionPostProduce : l10n.actionFindProduce),
        ),
        const SizedBox(height: SharedTokens.space3),
        _ToolStrip(
          tools: [
            _Tool(
              icon: Icons.compare_arrows,
              label: l10n.actionCompareMarkets,
              onTap: () => _pickCommodity(context, ref),
            ),
            _Tool(
              icon: Icons.notifications_active_outlined,
              label: l10n.actionPriceAlerts,
              onTap: () => context.go(Routes.alerts),
            ),
            _Tool(
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
                title: Text(c.nameIn(context)),
                subtitle: Text(c.altNameIn(context)),
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

/// Three secondary tools in one ruled strip, so they read as a toolbar, not as tiles.
class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.tools});
  final List<_Tool> tools;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radiusSmall),
        side: BorderSide(color: c.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tools.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: c.border),
              Expanded(child: tools[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SharedTokens.space2,
          vertical: SharedTokens.space3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(height: SharedTokens.space1),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
