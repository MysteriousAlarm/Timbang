import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/phone.dart';
import '../../auth/application/session.dart';
import '../application/profile_controller.dart';
import '../domain/user_profile.dart';
import 'municipality_field.dart';
import 'profile_form_text.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const Center(child: CircularProgressIndicator());
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = session.profile;
    final c = TimbangColors.of(context);
    final controller = ref.read(profileControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(SharedTokens.space4),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SharedTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.name, style: t.headlineSmall)),
                    OutlinedButton.icon(
                      key: const Key('editProfile'),
                      onPressed: () => _edit(context, ref, p),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.editProfile),
                    ),
                  ],
                ),
                const SizedBox(height: SharedTokens.space3),
                Wrap(
                  spacing: SharedTokens.space2,
                  runSpacing: SharedTokens.space2,
                  children: [
                    _Badge(
                      icon: Icons.badge_outlined,
                      label: roleLabel(l10n, session.role),
                      fill: Theme.of(context).colorScheme.secondary,
                      onFill: Theme.of(context).colorScheme.onSecondary,
                    ),
                    if (p.verified)
                      _Badge(
                        icon: Icons.verified,
                        label: l10n.verifiedBadge,
                        fill: c.confidenceHigh,
                        onFill: c.onConfidenceHigh,
                      ),
                  ],
                ),
                const Divider(height: SharedTokens.space6),
                _InfoRow(
                  icon: Icons.phone_android,
                  label: l10n.phoneReadOnly,
                  value: formatPhMobile(p.phone),
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: l10n.municipalityLabel,
                  value: p.municipality,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SharedTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: c.info),
                    const SizedBox(width: SharedTokens.space2),
                    Text(l10n.myData, style: t.titleMedium),
                  ],
                ),
                const SizedBox(height: SharedTokens.space2),
                Text(l10n.myDataBody, style: t.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: SharedTokens.space5),
        OutlinedButton.icon(
          key: const Key('signOut'),
          onPressed: controller.signOut,
          icon: const Icon(Icons.logout),
          label: Text(l10n.signOut),
        ),
        const SizedBox(height: SharedTokens.space3),
        TextButton.icon(
          key: const Key('deleteAccount'),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.deleteAccount),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, UserProfile p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(profile: p),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await ref.read(profileControllerProvider).deleteAccount();
    if (!deleted) messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late String? _municipality = widget.profile.municipality;
  bool _saving = false;
  ProfileFormError? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await ref
        .read(profileControllerProvider)
        .updateProfile(name: _name.text, municipality: _municipality);
    if (!mounted) return;
    if (err == null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saved)));
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SharedTokens.space5,
        0,
        SharedTokens.space5,
        MediaQuery.viewInsetsOf(context).bottom + SharedTokens.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SharedTokens.space3),
              child: Text(
                profileErrorText(l10n, _error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
              ),
            ),
          TextField(
            key: const Key('editNameField'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.nameLabel),
          ),
          const SizedBox(height: SharedTokens.space4),
          MunicipalityField(
            value: _municipality,
            onChanged: (v) => setState(() => _municipality = v),
          ),
          const SizedBox(height: SharedTokens.space5),
          FilledButton(
            key: const Key('saveEdit'),
            onPressed: _saving ? null : _save,
            child: Text(l10n.saveProfile),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SharedTokens.space2),
      child: Row(
        children: [
          Icon(icon, color: TimbangColors.of(context).textMuted),
          const SizedBox(width: SharedTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(value, style: t.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.fill, required this.onFill});
  final IconData icon;
  final String label;
  final Color fill;
  final Color onFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: onFill),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: onFill)),
        ],
      ),
    );
  }
}
