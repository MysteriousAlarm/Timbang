import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/timbang_logo.dart';

/// Shared frame for the login/OTP/setup screens: logo on top, narrow centered column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.children, this.leading});

  final String title;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SharedTokens.space5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null) Align(alignment: Alignment.centerLeft, child: leading),
                  const Center(child: TimbangLogo(size: 36)),
                  const SizedBox(height: SharedTokens.space6),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: SharedTokens.space4),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: SharedTokens.space4),
        padding: const EdgeInsets.all(SharedTokens.space3),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(SharedTokens.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onError),
            const SizedBox(width: SharedTokens.space2),
            Expanded(
              child: Text(message, style: TextStyle(color: scheme.onError, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
