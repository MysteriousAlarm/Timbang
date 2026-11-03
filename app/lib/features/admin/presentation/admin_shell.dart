import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand.dart';
import '../../auth/application/session.dart';
import '../../profile/application/profile_controller.dart';
import '../data/admin_repository.dart';

/// Admin dashboard frame (Forest and Gold): seal header, side navigation.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _routes = [
    Routes.admin,
    Routes.adminCommodities,
    Routes.adminMarkets,
    Routes.adminPrices,
    Routes.adminUsers,
    Routes.adminModeration,
    Routes.adminSms,
    Routes.adminAudit,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final name = session is SignedIn ? session.profile.name : '';
    final width = MediaQuery.sizeOf(context).width;
    final openFlags = ref.watch(openAbuseProvider).value?.length ?? 0;
    final narrow = width < 700;
    final items = <({Widget icon, Widget selectedIcon, String label})>[
      (
        icon: const Icon(Icons.space_dashboard_outlined),
        selectedIcon: const Icon(Icons.space_dashboard),
        label: l10n.adminOverview,
      ),
      (
        icon: const Icon(Icons.eco_outlined),
        selectedIcon: const Icon(Icons.eco),
        label: l10n.adminCommodities,
      ),
      (
        icon: const Icon(Icons.storefront_outlined),
        selectedIcon: const Icon(Icons.storefront),
        label: l10n.adminMarkets,
      ),
      (
        icon: const Icon(Icons.price_change_outlined),
        selectedIcon: const Icon(Icons.price_change),
        label: l10n.adminPrices,
      ),
      (
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: l10n.adminUsers,
      ),
      (
        icon: Badge(
          isLabelVisible: openFlags > 0,
          label: Text('$openFlags'),
          child: const Icon(Icons.shield_outlined),
        ),
        selectedIcon: const Icon(Icons.shield),
        label: l10n.adminModeration,
      ),
      (
        icon: const Icon(Icons.sms_outlined),
        selectedIcon: const Icon(Icons.sms),
        label: l10n.adminSms,
      ),
      (
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: l10n.adminAudit,
      ),
    ];
    final index = _routes
        .lastIndexWhere((r) => location.startsWith(r))
        .clamp(0, _routes.length - 1);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            narrow
                ? const TimbangEmblem(size: 34, onDark: true)
                : const TimbangWordmark(size: 40, onDark: true),
            SizedBox(width: narrow ? SharedTokens.space2 : SharedTokens.space4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.highlight, borderRadius: BorderRadius.circular(6)),
              child: Text(
                l10n.adminBadge,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.onHighlight),
              ),
            ),
          ],
        ),
        actions: [
          if (width >= 700)
            Padding(
              padding: const EdgeInsets.only(right: SharedTokens.space2),
              child: Center(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.adminFarmerView,
            icon: const Icon(Icons.phone_android),
            onPressed: () => context.go(Routes.prices),
          ),
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: ref.read(profileControllerProvider).signOut,
          ),
          const SizedBox(width: SharedTokens.space2),
        ],
      ),
      // Phones: a slide-out menu; tablets and desktops: a side rail.
      drawer: narrow
          ? NavigationDrawer(
              selectedIndex: index,
              onDestinationSelected: (i) {
                Navigator.pop(context);
                context.go(_routes[i]);
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
                  child: Text(name, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final d in items)
                  NavigationDrawerDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
                  ),
              ],
            )
          : null,
      body: narrow
          ? child
          : Row(
              children: [
                NavigationRail(
                  extended: width >= 1100,
                  minExtendedWidth: 232,
                  selectedIndex: index,
                  labelType: width >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  onDestinationSelected: (i) => context.go(_routes[i]),
                  destinations: [
                    for (final d in items)
                      NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon,
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: c.border),
                Expanded(child: child),
              ],
            ),
    );
  }
}

/// Standard admin page: kicker + title + actions, then content, max 1200 wide.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.kicker,
    required this.title,
    required this.children,
    this.actions = const [],
    this.description,
  });

  final String kicker;
  final String title;
  final String? description;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 800;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker, style: t.labelMedium?.copyWith(color: TimbangColors.of(context).textMuted)),
        const SizedBox(height: 2),
        Text(title, style: t.headlineMedium),
        if (description != null) ...[
          const SizedBox(height: SharedTokens.space2),
          Text(
            description!,
            style: t.bodyMedium?.copyWith(color: TimbangColors.of(context).textMuted),
          ),
        ],
      ],
    );
    return ListView(
      padding: EdgeInsets.all(narrow ? SharedTokens.space4 : SharedTokens.space6),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (narrow || actions.isEmpty) ...[
                  heading,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: SharedTokens.space4),
                    Wrap(
                      spacing: SharedTokens.space3,
                      runSpacing: SharedTokens.space3,
                      children: actions,
                    ),
                  ],
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: SharedTokens.space4),
                      Wrap(spacing: SharedTokens.space3, children: actions),
                    ],
                  ),
                const SizedBox(height: SharedTokens.space5),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
