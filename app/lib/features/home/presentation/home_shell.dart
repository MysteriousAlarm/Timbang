import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/sections.dart';
import '../../auth/application/session.dart';
import '../../inquiries/data/inquiry_repository.dart';

/// Farmer/buyer frame: seal app bar with a highlight rule, labeled bottom navigation.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final signedIn = session is SignedIn ? session : null;
    final c = TimbangColors.of(context);
    final unread = ref.watch(newInquiryCountProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: const TimbangWordmark(size: 32, onDark: true),
        actions: [
          if (signedIn?.isAdmin ?? false)
            IconButton(
              key: const Key('appBarAdmin'),
              tooltip: l10n.openAdminDashboard,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.go(Routes.admin),
            ),
          if (signedIn != null)
            Padding(
              padding: const EdgeInsets.only(right: SharedTokens.space3),
              child: _Avatar(
                name: signedIn.profile.name,
                tooltip: l10n.navProfile,
                onTap: () => context.go(Routes.profile),
              ),
            ),
        ],
      ),
      // Farmers: the one main action, on the price board only.
      floatingActionButton: shell.currentIndex == 0 && signedIn?.role == Role.farmer
          ? FloatingActionButton.extended(
              key: const Key('fabPost'),
              backgroundColor: c.cta,
              foregroundColor: c.onCta,
              elevation: 2,
              onPressed: () => context.push(Routes.newListing),
              icon: const Icon(Icons.add),
              label: Text(l10n.actionPostProduce),
            )
          : null,
      body: Column(
        children: [
          if (signedIn?.profile.isSuspended ?? false)
            NoticeBanner(icon: Icons.block, message: l10n.suspendedNotice, kind: NoticeKind.error),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: l10n.navListings,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.forum_outlined),
              ),
              selectedIcon: const Icon(Icons.forum),
              label: l10n.navInquiries,
            ),
            NavigationDestination(
              icon: const Icon(Icons.notifications_outlined),
              selectedIcon: const Icon(Icons.notifications),
              label: l10n.navAlerts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.tooltip, required this.onTap});
  final String name;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.onPrimary, shape: BoxShape.circle),
          child: Text(
            initials(name),
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// "Maria Santos" -> "MS"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Max-width wrapper so phone-first screens stay readable in a desktop browser.
class PhoneWidth extends StatelessWidget {
  const PhoneWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child),
  );
}
