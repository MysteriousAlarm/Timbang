import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../data/admin_repository.dart';
import 'admin_shell.dart';

/// Admin: try the SMS price query exactly as a basic-phone user would (no SMS is sent).
class AdminSmsPage extends ConsumerStatefulWidget {
  const AdminSmsPage({super.key});

  @override
  ConsumerState<AdminSmsPage> createState() => _AdminSmsPageState();
}

class _AdminSmsPageState extends ConsumerState<AdminSmsPage> {
  final _text = TextEditingController(text: 'PRESYO KAMATIS BAYOMBONG');
  final _thread = <(bool, String)>[];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _busy = true;
      _thread.add((true, msg));
    });
    try {
      final reply = await ref.read(adminRepositoryProvider).simulateSms(msg);
      setState(() => _thread.add((false, reply)));
    } catch (_) {
      if (mounted) setState(() => _thread.add((false, AppLocalizations.of(context).errGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdminPage(
      kicker: l10n.smsKicker,
      title: l10n.adminSms,
      description: l10n.adminSmsDesc,
      children: [
        NoticeBanner(icon: Icons.info_outline, kind: NoticeKind.info, message: l10n.smsGatewayNote),
        const SizedBox(height: SharedTokens.space4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sms_outlined, color: c.textMuted),
                      const SizedBox(width: SharedTokens.space2),
                      Text(l10n.smsPhoneTitle, style: t.titleSmall),
                    ],
                  ),
                  const Divider(height: SharedTokens.space5),
                  if (_thread.isEmpty) Text(l10n.smsTryHint, style: t.bodySmall),
                  for (final (mine, text) in _thread)
                    Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        key: mine ? null : const Key('smsReply'),
                        margin: const EdgeInsets.only(bottom: SharedTokens.space2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: mine ? scheme.primary : c.surfaceMuted,
                          borderRadius: BorderRadius.circular(SharedTokens.radius),
                        ),
                        child: Text(
                          text,
                          style: t.bodyMedium?.copyWith(
                            color: mine ? scheme.onPrimary : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: SharedTokens.space2),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('smsInput'),
                          controller: _text,
                          maxLength: 160,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: l10n.smsInputLabel,
                            counterText: '',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: SharedTokens.space2),
                      IconButton.filled(
                        key: const Key('smsSend'),
                        tooltip: l10n.askSend,
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        Text(l10n.smsExamples, style: t.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
