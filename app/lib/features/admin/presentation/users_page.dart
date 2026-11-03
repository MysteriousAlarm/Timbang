import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/utils/phone.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_form_text.dart';
import '../data/admin_repository.dart';
import 'admin_shell.dart';

/// Admin: users, roles (reporter approval), market assignment, suspension.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _q = '';
  Role? _role;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.errGeneric} ($e)')));
    }
  }

  Future<void> _changeRole(AdminUser u) async {
    final l10n = AppLocalizations.of(context);
    final role = await showDialog<Role>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.changeRoleFor(u.profile.name)),
        children: [
          for (final r in Role.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: ListTile(
                leading: Icon(
                  r == u.profile.role ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                ),
                title: Text(roleLabel(l10n, r)),
                subtitle: Text(switch (r) {
                  Role.reporter => l10n.roleReporterHelp,
                  Role.admin => l10n.roleAdminHelp,
                  _ => '',
                }),
              ),
            ),
        ],
      ),
    );
    if (role == null || role == u.profile.role) return;
    await _run(() => ref.read(adminRepositoryProvider).setRole(u.profile.uid, role));
  }

  Future<void> _assignMarkets(AdminUser u) async {
    final l10n = AppLocalizations.of(context);
    final markets = (ref.read(marketsProvider).value ?? const <Market>[])
        .where((m) => m.active)
        .toList();
    final chosen = {...u.assignedMarketIds};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l10n.assignMarketsFor(u.profile.name)),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(l10n.assignMarketsHelp, style: Theme.of(ctx).textTheme.bodySmall),
                for (final m in markets)
                  CheckboxListTile(
                    value: chosen.contains(m.id),
                    onChanged: (v) =>
                        setD(() => v == true ? chosen.add(m.id) : chosen.remove(m.id)),
                    title: Text(m.name),
                    subtitle: Text(m.municipality),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _run(
        () => ref.read(adminRepositoryProvider).setReporterMarkets(u.profile.uid, chosen.toList()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final async = ref.watch(adminUsersProvider);
    // Keep the market list loaded for the assignment dialog.
    ref.watch(marketsProvider);
    final me = ref.watch(sessionProvider);
    final myUid = me is SignedIn ? me.user.uid : null;
    return AdminPage(
      kicker: l10n.adminPeopleKicker,
      title: l10n.adminUsers,
      description: l10n.adminUsersDesc,
      children: [
        Wrap(
          spacing: SharedTokens.space3,
          runSpacing: SharedTokens.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchUsersHint,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            SegmentedButton<Role?>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: null, label: Text(l10n.filterAll)),
                for (final r in Role.values)
                  ButtonSegment(value: r, label: Text(roleLabel(l10n, r))),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ],
        ),
        const SizedBox(height: SharedTokens.space4),
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              MessageView(icon: Icons.cloud_off, title: l10n.errGeneric, body: l10n.errNetwork),
          data: (all) {
            final list = all.where((u) {
              if (_role != null && u.profile.role != _role) {
                return false;
              }
              if (_q.isEmpty) {
                return true;
              }
              return '${u.profile.name} ${u.profile.phone} ${u.profile.municipality}'
                  .toLowerCase()
                  .contains(_q);
            }).toList();
            if (list.isEmpty) {
              return MessageView(icon: Icons.person_search, title: l10n.noMatches, body: '');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final u in list) ...[
                  PanelCard(
                    key: Key('user_${u.profile.uid}'),
                    child: Wrap(
                      spacing: SharedTokens.space4,
                      runSpacing: SharedTokens.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 260, maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.profile.name, style: t.titleMedium),
                              Text(
                                '${formatPhMobile(u.profile.phone)} · ${u.profile.municipality}',
                                style: t.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _Pill(
                                    label: roleLabel(l10n, u.profile.role),
                                    fill: Theme.of(context).colorScheme.secondary,
                                    on: Theme.of(context).colorScheme.onSecondary,
                                  ),
                                  if (u.profile.verified)
                                    _Pill(
                                      label: l10n.verifiedBadge,
                                      fill: c.confidenceHigh,
                                      on: c.onConfidenceHigh,
                                    ),
                                  if (u.profile.isSuspended)
                                    _Pill(
                                      label: l10n.suspended,
                                      fill: Theme.of(context).colorScheme.error,
                                      on: Theme.of(context).colorScheme.onError,
                                    ),
                                  if (u.reporterScore != null)
                                    _Pill(
                                      label: l10n.reporterScore((u.reporterScore! * 100).round()),
                                      fill: c.surfaceMuted,
                                      on: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  if (u.profile.role == Role.reporter)
                                    _Pill(
                                      label: u.assignedMarketIds.isEmpty
                                          ? l10n.anyMarket
                                          : l10n.marketsCount(u.assignedMarketIds.length),
                                      fill: c.primaryTint,
                                      on: Theme.of(context).colorScheme.onSurface,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (u.profile.uid != myUid)
                          Wrap(
                            spacing: SharedTokens.space2,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _changeRole(u),
                                icon: const Icon(Icons.badge_outlined),
                                label: Text(l10n.changeRole),
                              ),
                              if (u.profile.role == Role.reporter)
                                OutlinedButton.icon(
                                  onPressed: () => _assignMarkets(u),
                                  icon: const Icon(Icons.storefront_outlined),
                                  label: Text(l10n.assignMarkets),
                                ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: u.profile.isSuspended
                                      ? c.info
                                      : Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () => _run(
                                  () => ref
                                      .read(adminRepositoryProvider)
                                      .setStatus(
                                        u.profile.uid,
                                        u.profile.isSuspended
                                            ? AccountStatus.active
                                            : AccountStatus.suspended,
                                      ),
                                ),
                                icon: Icon(u.profile.isSuspended ? Icons.lock_open : Icons.block),
                                label: Text(u.profile.isSuspended ? l10n.reactivate : l10n.suspend),
                              ),
                            ],
                          )
                        else
                          Text(l10n.thisIsYou, style: t.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: SharedTokens.space2),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.fill, required this.on});
  final String label;
  final Color fill;
  final Color on;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: on)),
  );
}
