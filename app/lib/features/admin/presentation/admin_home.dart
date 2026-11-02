import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/timbang_logo.dart';
import '../../auth/application/session.dart';
import '../../profile/application/profile_controller.dart';

/// Admin dashboard shell (Forest and Gold). Sections arrive in Steps 2 and 8.
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            TimbangLogo(color: scheme.onPrimary),
            const SizedBox(width: 16),
            Text(l10n.adminTitle),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.navProfile,
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/app/profile'),
          ),
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: ref.read(profileControllerProvider).signOut,
          ),
        ],
      ),
      body: MessageView(
        icon: Icons.dashboard_outlined,
        title: l10n.comingSoonTitle,
        body: session is SignedIn ? '${session.profile.name} · ${l10n.comingSoonBody}' : '',
      ),
    );
  }
}
