import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/confidence.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/confidence_chip.dart';

const _maxWidth = 1120.0;

/// Public website landing page (Forest and Gold).
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _howKey = GlobalKey();
  final _trustKey = GlobalKey();

  void _scrollTo(GlobalKey key) => Scrollable.ensureVisible(
    key.currentContext!,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _UtilityStrip(),
            _Header(
              wide: wide,
              onHow: () => _scrollTo(_howKey),
              onTrust: () => _scrollTo(_trustKey),
            ),
            _Hero(wide: wide, onHow: () => _scrollTo(_howKey)),
            _Section(
              kicker: l10n.principlesKicker,
              title: l10n.principlesTitle,
              child: _Principles(wide: wide),
            ),
            _Section(
              key: _howKey,
              tinted: true,
              kicker: l10n.howKicker,
              title: l10n.howTitle,
              child: _Steps(wide: wide),
            ),
            _Section(
              key: _trustKey,
              kicker: l10n.trustKicker,
              title: l10n.trustTitle,
              child: _ConfidenceLegend(wide: wide),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Bounded extends StatelessWidget {
  const _Bounded({required this.child, this.vertical = 0});
  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SharedTokens.space5, vertical: vertical),
        child: child,
      ),
    ),
  );
}

class _UtilityStrip extends StatelessWidget {
  const _UtilityStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onPrimary);
    return Container(
      color: TimbangColors.of(context).primaryDark,
      child: _Bounded(
        vertical: 8,
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: scheme.onPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.utilityStrip, style: style, overflow: TextOverflow.ellipsis),
            ),
            Text(l10n.buildLabel(AppConfig.appVersion), style: style),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.wide, required this.onHow, required this.onTrust});
  final bool wide;
  final VoidCallback onHow;
  final VoidCallback onTrust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: _Bounded(
        vertical: 14,
        child: Row(
          children: [
            const TimbangWordmark(size: 44),
            const Spacer(),
            if (wide) ...[
              TextButton(onPressed: onHow, child: Text(l10n.howKicker)),
              TextButton(onPressed: onTrust, child: Text(l10n.trustKicker)),
              const SizedBox(width: SharedTokens.space3),
            ],
            FilledButton.icon(
              key: const Key('headerLogin'),
              onPressed: () => context.go(Routes.login),
              icon: const Icon(Icons.login),
              label: Text(l10n.logIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.onHow});
  final bool wide;
  final VoidCallback onHow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 4, width: 72, color: c.highlight),
        const SizedBox(height: SharedTokens.space4),
        Text(l10n.heroKicker.toUpperCase(), style: t.labelSmall?.copyWith(color: scheme.onPrimary)),
        const SizedBox(height: SharedTokens.space3),
        Text(
          l10n.tagline,
          style: (wide ? t.displaySmall?.copyWith(fontSize: 46) : t.displaySmall)?.copyWith(
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        Text(l10n.taglineSub, style: t.titleMedium?.copyWith(color: scheme.onPrimary)),
        const SizedBox(height: SharedTokens.space5),
        Wrap(
          spacing: SharedTokens.space3,
          runSpacing: SharedTokens.space3,
          children: [
            FilledButton.icon(
              key: const Key('landingCta'),
              style: FilledButton.styleFrom(backgroundColor: c.cta, foregroundColor: c.onCta),
              onPressed: () => context.go(Routes.login),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.landingCta),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onPrimary,
                side: BorderSide(color: scheme.onPrimary, width: 1.5),
              ),
              onPressed: onHow,
              child: Text(l10n.howKicker),
            ),
          ],
        ),
      ],
    );
    return Container(
      color: scheme.primary,
      child: TerracePattern(
        child: _Bounded(
          vertical: wide ? 72 : 48,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: SharedTokens.space6 * 1.5),
                    const Expanded(flex: 5, child: _SampleBoard()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: SharedTokens.space6),
                    const _SampleBoard(),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Illustrative preview of a price board row. Clearly labeled as an example,
/// never presented as a real price (CLAUDE.md Section 12).
class _SampleBoard extends StatelessWidget {
  const _SampleBoard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget row(String name, String price, IconData trend, String trendLabel, Confidence conf) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SharedTokens.space4,
            vertical: SharedTokens.space3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.titleSmall),
                    const SizedBox(height: 4),
                    ConfidenceChip(confidence: conf),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price, style: t.titleLarge?.copyWith(fontFeatures: tabularFigures)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trend, size: 16, color: c.textMuted),
                      const SizedBox(width: 2),
                      Text(trendLabel, style: t.bodySmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
    return Semantics(
      label: l10n.sampleBoardSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(SharedTokens.radiusLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: c.surfaceMuted,
              padding: const EdgeInsets.all(SharedTokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sampleBoardKicker.toUpperCase(), style: t.labelSmall),
                        Text(l10n.sampleBoardTitle, style: t.titleMedium),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: SharedTokens.notice,
                      border: Border.all(color: SharedTokens.noticeRule),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.exampleBadge,
                      style: t.labelSmall?.copyWith(color: SharedTokens.onNotice),
                    ),
                  ),
                ],
              ),
            ),
            row(l10n.sampleKamatis, '₱ ––.––', Icons.arrow_upward, l10n.trendUp, Confidence.high),
            const Divider(),
            row(
              l10n.sampleRepolyo,
              '₱ ––.––',
              Icons.trending_flat,
              l10n.trendFlat,
              Confidence.medium,
            ),
            const Divider(),
            row(l10n.sampleSitaw, '₱ ––.––', Icons.arrow_downward, l10n.trendDown, Confidence.low),
            Container(
              color: c.surfaceMuted,
              padding: const EdgeInsets.symmetric(
                horizontal: SharedTokens.space4,
                vertical: SharedTokens.space3,
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.sampleBoardFooter, style: t.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.kicker,
    required this.title,
    required this.child,
    this.tinted = false,
  });

  final String kicker;
  final String title;
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    return Container(
      color: tinted ? c.surfaceMuted : null,
      child: _Bounded(
        vertical: 64,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 28, height: 3, color: c.highlight),
                const SizedBox(width: SharedTokens.space2),
                Text(kicker.toUpperCase(), style: t.labelSmall),
              ],
            ),
            const SizedBox(height: SharedTokens.space2),
            Text(title, style: t.headlineMedium),
            const SizedBox(height: SharedTokens.space5),
            child,
          ],
        ),
      ),
    );
  }
}

/// Lays out cards in a row on wide screens and a column on phones.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (final ch in children)
            Padding(
              padding: const EdgeInsets.only(bottom: SharedTokens.space3),
              child: ch,
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: SharedTokens.space4),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.leading, required this.title, required this.body});
  final Widget leading;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        border: Border.all(color: TimbangColors.of(context).border),
      ),
      padding: const EdgeInsets.all(SharedTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(height: SharedTokens.space4),
          Text(title, style: t.titleMedium),
          const SizedBox(height: SharedTokens.space2),
          Text(body, style: t.bodyMedium?.copyWith(color: TimbangColors.of(context).textMuted)),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: TimbangColors.of(context).primaryTint,
      borderRadius: BorderRadius.circular(SharedTokens.radius),
    ),
    child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
  );
}

class _Principles extends StatelessWidget {
  const _Principles({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Responsive(
      wide: wide,
      children: [
        _InfoCard(
          leading: const _IconBadge(Icons.schedule),
          title: l10n.principleTimelyTitle,
          body: l10n.principleTimelyBody,
        ),
        _InfoCard(
          leading: const _IconBadge(Icons.place_outlined),
          title: l10n.principleLocalTitle,
          body: l10n.principleLocalBody,
        ),
        _InfoCard(
          leading: const _IconBadge(Icons.verified_outlined),
          title: l10n.principleTrustedTitle,
          body: l10n.principleTrustedBody,
        ),
        _InfoCard(
          leading: const _IconBadge(Icons.sms_outlined),
          title: l10n.principleAccessibleTitle,
          body: l10n.principleAccessibleBody,
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget number(int n) => Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$n',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
    return _Responsive(
      wide: wide,
      children: [
        _InfoCard(leading: number(1), title: l10n.step1Title, body: l10n.step1Body),
        _InfoCard(leading: number(2), title: l10n.step2Title, body: l10n.step2Body),
        _InfoCard(leading: number(3), title: l10n.step3Title, body: l10n.step3Body),
      ],
    );
  }
}

class _ConfidenceLegend extends StatelessWidget {
  const _ConfidenceLegend({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Responsive(
      wide: wide,
      children: [
        _InfoCard(
          leading: const ConfidenceChip(confidence: Confidence.high),
          title: l10n.legendHighTitle,
          body: l10n.legendHighBody,
        ),
        _InfoCard(
          leading: const ConfidenceChip(confidence: Confidence.medium),
          title: l10n.legendMediumTitle,
          body: l10n.legendMediumBody,
        ),
        _InfoCard(
          leading: const ConfidenceChip(confidence: Confidence.low),
          title: l10n.legendLowTitle,
          body: l10n.legendLowBody,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final on = Theme.of(context).colorScheme.onPrimary;
    final c = TimbangColors.of(context);
    return Container(
      color: c.primaryDark,
      child: _Bounded(
        vertical: 48,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TimbangWordmark(size: 44, onDark: true),
            const SizedBox(height: SharedTokens.space4),
            Text(l10n.landingDisclaimer, style: t.bodyMedium?.copyWith(color: on)),
            const SizedBox(height: SharedTokens.space2),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: on),
                const SizedBox(width: SharedTokens.space2),
                Flexible(
                  child: Text(l10n.privacyFooter, style: t.bodyMedium?.copyWith(color: on)),
                ),
              ],
            ),
            const SizedBox(height: SharedTokens.space5),
            Container(height: 1, color: on.withValues(alpha: 0.2)),
            const SizedBox(height: SharedTokens.space4),
            Text(
              '${l10n.footerCredit} · ${l10n.buildLabel(AppConfig.appVersion)}',
              style: t.bodySmall?.copyWith(color: on),
            ),
          ],
        ),
      ),
    );
  }
}
