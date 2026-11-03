import 'package:flutter/material.dart';

import '../../core/theme/timbang_colors.dart';
import '../../core/theme/tokens.dart';

/// Empty / offline / error / coming-soon states (required on every screen).
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SharedTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: TimbangColors.of(context).textMuted),
            const SizedBox(height: SharedTokens.space4),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: SharedTokens.space2),
            Text(body, style: t.bodyLarge, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: SharedTokens.space5), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// The ONE cta-colored action on a screen.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 3, color: c.onCta),
          )
        : Text(label);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: c.cta, foregroundColor: c.onCta),
        onPressed: loading ? null : onPressed,
        icon: loading || icon == null ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
    );
  }
}
