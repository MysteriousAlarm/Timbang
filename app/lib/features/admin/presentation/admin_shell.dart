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

/// Admin dashboard frame (Forest and Gold): seal header, side navigation.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _routes = [Routes.admin, Routes.adminCommodities, Routes.adminMarkets];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final name = session is SignedIn ? session.profile.name : '';
    final width = MediaQuery.sizeOf(context).width;
    final index = _routes.lastIndexWhere((r) => location.startsWith(r)).clamp(0, 2);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            const TimbangWordmark(size: 40, onDark: true),
            const SizedBox(width: SharedTokens.space4),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, color: c.highlight),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: width >= 1100,
            minExtendedWidth: 232,
            selectedIndex: index,
            labelType: width >= 1100 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            onDestinationSelected: (i) => context.go(_routes[i]),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.space_dashboard_outlined),
                selectedIcon: const Icon(Icons.space_dashboard),
                label: Text(l10n.adminOverview),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.eco_outlined),
                selectedIcon: const Icon(Icons.eco),
                label: Text(l10n.adminCommodities),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront),
                label: Text(l10n.adminMarkets),
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
        Text(kicker.toUpperCase(), style: t.labelSmall),
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
