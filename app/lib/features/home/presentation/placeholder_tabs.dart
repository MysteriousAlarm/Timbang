import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';

/// Price board tab until Step 4. Empty state, never fake prices.
class PriceBoardPlaceholder extends StatelessWidget {
  const PriceBoardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MessageView(
      icon: Icons.price_change_outlined,
      title: l10n.priceBoardEmptyTitle,
      body: l10n.priceBoardEmptyBody,
    );
  }
}

class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MessageView(icon: icon, title: l10n.comingSoonTitle, body: l10n.comingSoonBody);
  }
}
