import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/confidence.dart';
import '../../../shared/widgets/confidence_chip.dart';
import '../../../shared/widgets/timbang_logo.dart';

/// Public website landing page (Forest and Gold).
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: TimbangLogo(color: scheme.onPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: SharedTokens.space4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onPrimary,
                side: BorderSide(color: scheme.onPrimary),
              ),
              onPressed: () => context.go('/login'),
              child: Text(l10n.logIn),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: SharedTokens.space5,
                vertical: SharedTokens.space6 * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4, width: 72, color: c.highlight),
                      const SizedBox(height: SharedTokens.space4),
                      Text(l10n.tagline, style: t.displaySmall?.copyWith(color: scheme.onPrimary)),
                      const SizedBox(height: SharedTokens.space3),
                      Text(
                        l10n.taglineSub,
                        style: t.titleMedium?.copyWith(color: scheme.onPrimary),
                      ),
                      const SizedBox(height: SharedTokens.space5),
                      FilledButton.icon(
                        key: const Key('landingCta'),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.cta,
                          foregroundColor: c.onCta,
                        ),
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.landingCta),
                      ),
                      const SizedBox(height: SharedTokens.space5),
                      const Wrap(
                        spacing: SharedTokens.space2,
                        runSpacing: SharedTokens.space2,
                        children: [
                          ConfidenceChip(confidence: Confidence.high),
                          ConfidenceChip(confidence: Confidence.medium),
                          ConfidenceChip(confidence: Confidence.low),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SharedTokens.space5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final cards = [
                      _Feature(
                        Icons.verified_outlined,
                        l10n.landingFeature1Title,
                        l10n.landingFeature1Body,
                      ),
                      _Feature(
                        Icons.handshake_outlined,
                        l10n.landingFeature2Title,
                        l10n.landingFeature2Body,
                      ),
                      _Feature(
                        Icons.sms_outlined,
                        l10n.landingFeature3Title,
                        l10n.landingFeature3Body,
                      ),
                    ];
                    if (box.maxWidth < 720) {
                      return Column(
                        children: [
                          for (final f in cards)
                            Padding(
                              padding: const EdgeInsets.only(bottom: SharedTokens.space4),
                              child: f,
                            ),
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: SharedTokens.space4),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SharedTokens.space5,
                0,
                SharedTokens.space5,
                SharedTokens.space6,
              ),
              child: Text(l10n.landingDisclaimer, style: t.bodySmall, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SharedTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: SharedTokens.space3),
            Text(title, style: t.titleMedium),
            const SizedBox(height: SharedTokens.space2),
            Text(body, style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}
