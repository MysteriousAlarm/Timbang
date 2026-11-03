import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';

/// Opens the full RA 10173 privacy notice. Returns true when the user scrolled to the end,
/// ticked the checkbox and tapped Agree. With [requireAgreement] false it is read-only.
Future<bool> showPrivacyNotice(BuildContext context, {bool requireAgreement = true}) async {
  final agreed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PrivacyNoticeScreen(requireAgreement: requireAgreement),
    ),
  );
  return agreed ?? false;
}

class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({super.key, this.requireAgreement = true});
  final bool requireAgreement;

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_check);
    // Short screens or large windows may show everything without scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_reachedEnd || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent <= 0 || p.pixels >= p.maxScrollExtent - 24) {
      setState(() => _reachedEnd = true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sections = [
      (Icons.badge_outlined, l10n.privacyCollectTitle, l10n.privacyCollectBody),
      (Icons.flag_outlined, l10n.privacyWhyTitle, l10n.privacyWhyBody),
      (Icons.visibility_outlined, l10n.privacyShareTitle, l10n.privacyShareBody),
      (Icons.schedule, l10n.privacyKeepTitle, l10n.privacyKeepBody),
      (Icons.gavel_outlined, l10n.privacyRightsTitle, l10n.privacyRightsBody),
      (Icons.lock_outline, l10n.privacySecurityTitle, l10n.privacySecurityBody),
      (Icons.mail_outline, l10n.privacyContactTitle, l10n.privacyContactBody),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, color: c.highlight),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            key: const Key('privacyScroll'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text('REPUBLIC ACT NO. 10173', style: t.labelSmall),
              const SizedBox(height: 4),
              Text(l10n.privacyHeading, style: t.headlineSmall),
              const SizedBox(height: SharedTokens.space3),
              Text(l10n.privacyIntro, style: t.bodyLarge),
              const SizedBox(height: SharedTokens.space5),
              for (final (icon, title, body) in sections) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.primaryTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: scheme.primary, size: 22),
                    ),
                    const SizedBox(width: SharedTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.titleMedium),
                          const SizedBox(height: 4),
                          Text(body, style: t.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SharedTokens.space5),
              ],
              Text(l10n.privacyUpdated, style: t.bodySmall),
              const SizedBox(height: SharedTokens.space2),
              Container(key: const Key('privacyEnd'), height: 1, color: c.border),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.requireAgreement
          ? SafeArea(
              child: Material(
                color: scheme.surface,
                shape: Border(top: BorderSide(color: c.border)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_reachedEnd)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.south, size: 18, color: c.textMuted),
                              const SizedBox(width: 6),
                              Expanded(child: Text(l10n.privacyScrollHint, style: t.bodySmall)),
                            ],
                          ),
                        ),
                      CheckboxListTile(
                        key: const Key('privacyCheck'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _checked,
                        onChanged: _reachedEnd
                            ? (v) => setState(() => _checked = v ?? false)
                            : null,
                        title: Text(l10n.privacyAgreeCheck, style: t.titleSmall),
                      ),
                      FilledButton(
                        key: const Key('privacyAgree'),
                        onPressed: _checked ? () => Navigator.pop(context, true) : null,
                        child: Text(l10n.privacyAgreeButton),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
