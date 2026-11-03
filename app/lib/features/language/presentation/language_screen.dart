import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand.dart';

/// First launch: pick the app language. Shown in both languages on purpose.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.primary,
            child: TerracePattern(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TimbangWordmark(size: 44, onDark: true),
                      const SizedBox(height: 28),
                      Text(
                        'Choose your language',
                        style: t.headlineSmall?.copyWith(color: scheme.onPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Piliin ang iyong wika',
                        style: t.titleMedium?.copyWith(color: scheme.onPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(SharedTokens.space5),
                  children: [
                    _LanguageCard(
                      key: const Key('lang_en'),
                      title: 'English',
                      subtitle: 'Use TIMBANG in English',
                      badge: 'EN',
                      onTap: () => ref.read(languageProvider.notifier).choose(AppLanguage.english),
                    ),
                    const SizedBox(height: SharedTokens.space3),
                    _LanguageCard(
                      key: const Key('lang_fil'),
                      title: 'Filipino',
                      subtitle: 'Gamitin ang TIMBANG sa Filipino',
                      badge: 'FIL',
                      onTap: () => ref.read(languageProvider.notifier).choose(AppLanguage.filipino),
                    ),
                    const SizedBox(height: SharedTokens.space5),
                    Text(
                      'You can change this later in Profile.\nMaaari itong palitan sa Profile.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radiusLarge),
        side: BorderSide(color: c.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SharedTokens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SharedTokens.space4),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primaryTint, shape: BoxShape.circle),
                child: Text(
                  badge,
                  style: t.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: SharedTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleLarge),
                    Text(subtitle, style: t.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
