import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/phone.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/phone_auth_controller.dart';
import 'auth_error_text.dart';
import 'auth_scaffold.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _changeNumber() {
    ref.read(phoneAuthControllerProvider.notifier).reset();
    context.go('/login');
  }

  Future<void> _resend(String phone) async {
    _code.clear();
    await ref.read(phoneAuthControllerProvider.notifier).sendCode(phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(phoneAuthControllerProvider);
    final phone = state.phone;
    if (phone == null) {
      // Deep-linked without a pending verification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const SizedBox.shrink();
    }
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    return AuthScaffold(
      step: l10n.stepOf(2, 3),
      title: l10n.otpTitle,
      subtitle: l10n.otpSentTo(formatPhMobile(phone)),
      leading: IconButton(
        tooltip: l10n.changeNumber,
        icon: const Icon(Icons.arrow_back),
        onPressed: _changeNumber,
      ),
      children: [
        if (state.error != null) ErrorBanner(authErrorText(l10n, state.error!)),
        TextField(
          key: const Key('otpField'),
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(AppConfig.otpLength),
          ],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 12),
          decoration: InputDecoration(labelText: l10n.otpLabel),
          onChanged: (v) {
            if (v.length == AppConfig.otpLength) controller.verify(v);
          },
        ),
        const SizedBox(height: SharedTokens.space5),
        CtaButton(
          key: const Key('verify'),
          label: l10n.verify,
          icon: Icons.check,
          loading: state.loading,
          onPressed: () => controller.verify(_code.text),
        ),
        const SizedBox(height: SharedTokens.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: _changeNumber, child: Text(l10n.changeNumber)),
            TextButton(
              onPressed: state.loading ? null : () => _resend(phone),
              child: Text(l10n.resendCode),
            ),
          ],
        ),
      ],
    );
  }
}
