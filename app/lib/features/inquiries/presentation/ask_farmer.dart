import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../listings/domain/listing.dart';
import '../../reports/data/price_report_repository.dart' show SubmitError, SubmitFailure;
import '../data/inquiry_repository.dart';

/// The ONE cta on a buyer's listing view: send an inquiry to the farmer.
class AskFarmerButton extends StatelessWidget {
  const AskFarmerButton({super.key, required this.listing, required this.commodityName});
  final Listing listing;
  final String commodityName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    return FilledButton.icon(
      key: const Key('askFarmer'),
      style: FilledButton.styleFrom(backgroundColor: c.cta, foregroundColor: c.onCta),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _AskSheet(listing: listing, commodityName: commodityName),
      ),
      icon: const Icon(Icons.forum_outlined),
      label: Text(l10n.askFarmer),
    );
  }
}

class _AskSheet extends ConsumerStatefulWidget {
  const _AskSheet({required this.listing, required this.commodityName});
  final Listing listing;
  final String commodityName;

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  late final _msg = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_msg.text.isEmpty) {
      _msg.text = AppLocalizations.of(context).askTemplate(widget.commodityName);
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final text = _msg.text.trim();
    if (text.isEmpty || text.length > 500) {
      setState(() => _error = l10n.askErrLength);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inquiryRepositoryProvider).send(listingId: widget.listing.id, message: text);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.askSent)));
    } on SubmitFailure catch (f) {
      setState(() {
        _sending = false;
        _error = switch (f.error) {
          SubmitError.duplicate => l10n.askErrDuplicate,
          SubmitError.rateLimited => l10n.reportErrRateLimited,
          SubmitError.notFound => l10n.askErrGone,
          SubmitError.network => l10n.errNetwork,
          _ => l10n.errGeneric,
        };
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = l10n.errNetwork;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
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
          Text(l10n.askTitle(widget.listing.farmerName), style: t.titleLarge),
          const SizedBox(height: SharedTokens.space2),
          Text(l10n.askHelp, style: t.bodySmall),
          const SizedBox(height: SharedTokens.space4),
          if (_error != null) ...[
            NoticeBanner(icon: Icons.error_outline, message: _error!, kind: NoticeKind.error),
            const SizedBox(height: SharedTokens.space3),
          ],
          TextField(
            key: const Key('askMessage'),
            controller: _msg,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(labelText: l10n.askMessageLabel, alignLabelWithHint: true),
          ),
          const SizedBox(height: SharedTokens.space3),
          FilledButton.icon(
            key: const Key('askSend'),
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(l10n.askSend),
          ),
        ],
      ),
    );
  }
}
