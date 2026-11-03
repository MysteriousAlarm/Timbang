import 'package:flutter/material.dart';

import '../../core/theme/timbang_colors.dart';
import '../../core/theme/tokens.dart';

/// Section title with an optional trailing action. [kicker] is read by screen readers
/// as context but not drawn: a small-caps label over every title is visual noise.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.kicker, required this.title, this.trailing});

  final String kicker;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      hint: kicker,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: Theme.of(context).textTheme.titleLarge)],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

enum NoticeKind { notice, info, error }

/// Full-width notice strip: demo data, offline, suspended account.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.icon,
    required this.message,
    this.kind = NoticeKind.notice,
    this.action,
  });

  final IconData icon;
  final String message;
  final NoticeKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final (Color fill, Color fg, Color rule) = switch (kind) {
      NoticeKind.notice => (SharedTokens.notice, SharedTokens.onNotice, SharedTokens.noticeRule),
      NoticeKind.info => (c.primaryTint, scheme.onSurface, scheme.primary),
      NoticeKind.error => (scheme.error, scheme.onError, scheme.error),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: fill,
          border: Border(left: BorderSide(color: rule, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SharedTokens.space4,
          vertical: SharedTokens.space3,
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: SharedTokens.space3),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A bordered card with a section header row.
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding, this.accent = false});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Primary-colored outline for the one panel that matters most on a screen.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Material (not a decorated Container) so ink splashes of tiles inside stay visible.
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        side: accent ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide(color: c.border),
      ),
      child: Padding(padding: padding ?? const EdgeInsets.all(SharedTokens.space4), child: child),
    );
  }
}
