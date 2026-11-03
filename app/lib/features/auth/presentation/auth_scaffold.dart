import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/sections.dart';

/// Shared frame for login / OTP / setup.
/// Phone: brand band on top, form sheet below. Wide screens: formal split layout.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.step,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? leading;

  /// e.g. "Hakbang 1 ng 3"
  final String? step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final form = _FormColumn(
            title: title,
            subtitle: subtitle,
            step: step,
            leading: leading,
            children: children,
          );
          if (box.maxWidth >= 900) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: 6,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(SharedTokens.space6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandBand(),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: TimbangColors.of(context).canvas,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(SharedTokens.radiusLarge + 4),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      SharedTokens.space5,
                      SharedTokens.space5,
                      SharedTokens.space5,
                      SharedTokens.space4,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.title,
    required this.children,
    this.subtitle,
    this.step,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final String? step;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leading != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: SharedTokens.space2),
              child: leading,
            ),
          ),
        if (step != null) ...[
          Text(step!, style: t.labelSmall),
          const SizedBox(height: SharedTokens.space1),
        ],
        Text(title, style: t.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: SharedTokens.space2),
          Text(
            subtitle!,
            style: t.bodyMedium?.copyWith(color: TimbangColors.of(context).textMuted),
          ),
        ],
        const SizedBox(height: SharedTokens.space5),
        ...children,
        const SizedBox(height: SharedTokens.space6),
        const _PrivacyFooter(),
      ],
    );
  }
}

class _BrandBand extends StatelessWidget {
  const _BrandBand();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: TimbangColors.of(context).primaryDark,
      child: TerracePattern(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SharedTokens.space5,
              SharedTokens.space5,
              SharedTokens.space5,
              SharedTokens.space6 + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TimbangWordmark(size: 44, onDark: true),
                const SizedBox(height: SharedTokens.space5),
                Text(
                  l10n.tagline,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: scheme.onPrimary, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: SharedTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onPrimary, size: 22),
          const SizedBox(width: SharedTokens.space3),
          Expanded(
            child: Text(text, style: t.bodyLarge?.copyWith(color: scheme.onPrimary)),
          ),
        ],
      ),
    );
    return Container(
      color: c.primaryDark,
      child: TerracePattern(
        child: Padding(
          padding: const EdgeInsets.all(SharedTokens.space6 + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TimbangWordmark(size: 52, onDark: true),
              const Spacer(),
              Text(l10n.tagline, style: t.displaySmall?.copyWith(color: scheme.onPrimary)),
              const SizedBox(height: SharedTokens.space5),
              point(Icons.verified_outlined, l10n.landingFeature1Title),
              point(Icons.handshake_outlined, l10n.landingFeature2Title),
              point(Icons.wifi_off_outlined, l10n.landingFeature3Title),
              const Spacer(),
              Text(l10n.landingDisclaimer, style: t.bodySmall?.copyWith(color: scheme.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: SharedTokens.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: TimbangColors.of(context).textMuted),
            const SizedBox(width: SharedTokens.space2),
            Flexible(child: Text(l10n.privacyFooter, style: t.bodySmall)),
          ],
        ),
        const SizedBox(height: SharedTokens.space1),
        Text(l10n.buildLabel(AppConfig.appVersion), style: t.bodySmall),
      ],
    );
  }
}

/// Inline error shown above a form.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: SharedTokens.space4),
    child: NoticeBanner(icon: Icons.error_outline, message: message, kind: NoticeKind.error),
  );
}
