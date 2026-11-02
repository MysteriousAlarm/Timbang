import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/phone_auth_controller.dart';
import 'auth_error_text.dart';
import 'auth_scaffold.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sent = await ref.read(phoneAuthControllerProvider.notifier).sendCode(_phone.text);
    if (sent && mounted) context.go('/login/otp');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(phoneAuthControllerProvider);
    return AuthScaffold(
      title: l10n.loginTitle,
      children: [
        if (state.error != null) ErrorBanner(authErrorText(l10n, state.error!)),
        TextField(
          key: const Key('phoneField'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]')),
            LengthLimitingTextInputFormatter(16),
          ],
          style: Theme.of(context).textTheme.titleLarge,
          decoration: InputDecoration(
            labelText: l10n.phoneLabel,
            hintText: l10n.phoneHint,
            prefixIcon: const Icon(Icons.phone_android),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: SharedTokens.space2),
        Text(l10n.phoneHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: SharedTokens.space5),
        CtaButton(
          key: const Key('sendCode'),
          label: l10n.sendCode,
          icon: Icons.sms_outlined,
          loading: state.loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
