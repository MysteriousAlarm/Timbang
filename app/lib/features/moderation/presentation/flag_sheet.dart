import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/application/session.dart';
import '../data/abuse_repository.dart';

String abuseReasonLabel(AppLocalizations l10n, String r) => switch (r) {
  'wrong_price' => l10n.abuseWrongPrice,
  'scam' => l10n.abuseScam,
  'spam' => l10n.abuseSpam,
  'offensive' => l10n.abuseOffensive,
  _ => l10n.abuseOther,
};

/// "I-report" link: flags a listing or a board price for admin review.
class FlagButton extends StatelessWidget {
  const FlagButton({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.label,
  });
  final String targetType;
  final String targetId;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('flagButton'),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FlagSheet(targetType: targetType, targetId: targetId),
    ),
    icon: const Icon(Icons.flag_outlined),
    label: Text(label),
  );
}

class _FlagSheet extends ConsumerStatefulWidget {
  const _FlagSheet({required this.targetType, required this.targetId});
  final String targetType;
  final String targetId;

  @override
  ConsumerState<_FlagSheet> createState() => _FlagSheetState();
}

class _FlagSheetState extends ConsumerState<_FlagSheet> {
  String? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final s = ref.read(sessionProvider);
    if (_reason == null || s is! SignedIn) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(abuseRepositoryProvider)
          .flag(
            uid: s.user.uid,
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason!,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.flagSent)));
    } catch (_) {
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep the session subscribed so it is ready when the user taps send.
    ref.watch(sessionProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SharedTokens.space5,
        0,
        SharedTokens.space5,
        MediaQuery.viewInsetsOf(context).bottom + SharedTokens.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.flagTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SharedTokens.space2),
          Text(l10n.flagHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SharedTokens.space3),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final r in abuseReasons)
                  RadioListTile<String>(
                    key: Key('reason_$r'),
                    value: r,
                    title: Text(abuseReasonLabel(l10n, r)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: InputDecoration(labelText: l10n.flagNote),
          ),
          const SizedBox(height: SharedTokens.space2),
          FilledButton.icon(
            key: const Key('flagSend'),
            onPressed: _reason == null || _sending ? null : _send,
            icon: const Icon(Icons.flag),
            label: Text(l10n.flagSend),
          ),
        ],
      ),
    );
  }
}
