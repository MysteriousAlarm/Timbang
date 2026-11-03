import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Home: today's price bulletin for the chosen market, then the services list.
/// Farmers post produce from the floating button (see HomeShell).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final isFarmer = session.role == Role.farmer;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const PriceBoardSection(),
        const SizedBox(height: SharedTokens.space6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SharedTokens.space4),
          child: Semantics(header: true, child: Text(l10n.servicesTitle, style: t.titleLarge)),
        ),
        const SizedBox(height: SharedTokens.space3),
        _ServiceList(
          items: [
            if (!isFarmer)
              _Service(
                icon: Icons.search,
                title: l10n.actionFindProduce,
                body: l10n.svcFindDesc,
                onTap: () => context.go(Routes.listings),
              ),
            _Service(
              key: const Key('tileReport'),
              icon: Icons.edit_note,
              title: l10n.actionReportPrice,
              body: l10n.svcReportDesc,
              onTap: () => context.push(Routes.report),
            ),
            _Service(
              icon: Icons.compare_arrows,
              title: l10n.actionCompareMarkets,
              body: l10n.svcCompareDesc,
              onTap: () => _pickCommodity(context, ref),
            ),
            _Service(
              icon: Icons.notifications_active_outlined,
              title: l10n.actionPriceAlerts,
              body: l10n.svcAlertsDesc,
              onTap: () => context.go(Routes.alerts),
            ),
          ],
        ),
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

/// Civic-style list of services: icon, name, one plain sentence, chevron. Full width.
class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.items});
  final List<_Service> items;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.symmetric(horizontal: BorderSide(color: c.border)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 64, color: c.border),
              items[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Service extends StatelessWidget {
  const _Service({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SharedTokens.space4,
          SharedTokens.space3,
          SharedTokens.space3,
          SharedTokens.space3,
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: scheme.primary, size: 26)),
            const SizedBox(width: SharedTokens.space4 + 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(body, style: t.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
