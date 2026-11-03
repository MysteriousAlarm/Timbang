import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';

class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MessageView(icon: icon, title: l10n.comingSoonTitle, body: l10n.comingSoonBody);
  }
}
