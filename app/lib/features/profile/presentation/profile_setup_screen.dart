import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_scaffold.dart';
import '../../privacy/presentation/privacy_notice_screen.dart';
import '../application/profile_controller.dart';
import 'municipality_field.dart';
import 'profile_form_text.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  String? _municipality;
  Role? _role;
  bool _consent = false;
  bool _saving = false;
  ProfileFormError? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref
        .read(profileControllerProvider)
        .createProfile(
          name: _name.text,
          municipality: _municipality,
          role: _role,
          consent: _consent,
        );
    // On success the session updates and the router moves on.
    if (mounted) {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return AuthScaffold(
      step: l10n.stepOf(3, 3),
      title: l10n.setupTitle,
      subtitle: l10n.setupSubtitle,
      children: [
        if (_error != null) ErrorBanner(profileErrorText(l10n, _error!)),
        TextField(
          key: const Key('nameField'),
          controller: _name,
          maxLength: AppConfig.nameMaxLength,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: l10n.nameLabel,
            prefixIcon: const Icon(Icons.person_outline),
            counterText: '',
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        MunicipalityField(
          value: _municipality,
          onChanged: (v) => setState(() => _municipality = v),
        ),
        const SizedBox(height: SharedTokens.space5),
        Text(l10n.roleQuestion, style: t.labelSmall),
        const SizedBox(height: SharedTokens.space2),
        // Only farmer and buyer can be self-selected.
        for (final r in Role.selfSignup) ...[
          _RoleCard(role: r, selected: _role == r, onTap: () => setState(() => _role = r)),
          const SizedBox(height: SharedTokens.space2),
        ],
        const SizedBox(height: SharedTokens.space3),
        _ConsentCard(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: SharedTokens.space5),
        CtaButton(
          key: const Key('saveProfile'),
          label: l10n.saveProfile,
          icon: Icons.check,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final Role role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final (icon, title, desc) = switch (role) {
      Role.farmer => (Icons.agriculture, l10n.roleFarmer, l10n.roleFarmerDesc),
      _ => (Icons.shopping_basket_outlined, l10n.roleBuyer, l10n.roleBuyerDesc),
    };
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.primaryTint : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SharedTokens.radius),
          side: BorderSide(color: selected ? scheme.primary : c.border, width: selected ? 3 : 1.5),
        ),
        child: InkWell(
          key: Key('role_${role.name}'),
          borderRadius: BorderRadius.circular(SharedTokens.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SharedTokens.space4),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : c.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: selected ? scheme.onPrimary : scheme.primary),
                ),
                const SizedBox(width: SharedTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(desc, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : c.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    return PanelCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                value ? Icons.verified_user : Icons.privacy_tip_outlined,
                color: value ? c.confidenceHigh : c.info,
              ),
              const SizedBox(width: SharedTokens.space2),
              Expanded(child: Text(l10n.consentTitle, style: t.titleSmall)),
            ],
          ),
          const SizedBox(height: SharedTokens.space2),
          Text(value ? l10n.privacyAgreedStatus : l10n.privacySummary, style: t.bodyMedium),
          const SizedBox(height: SharedTokens.space3),
          value
              ? TextButton.icon(
                  onPressed: () => showPrivacyNotice(context, requireAgreement: false),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.privacyReadAgain),
                )
              : OutlinedButton.icon(
                  key: const Key('consentCheckbox'),
                  onPressed: () async {
                    final agreed = await showPrivacyNotice(context);
                    if (agreed) onChanged(true);
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.privacyReadButton),
                ),
        ],
      ),
    );
  }
}
