import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/utils/contact.dart';
import '../../../shared/utils/phone.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../../price_board/application/board_providers.dart';
import '../../price_board/presentation/board_widgets.dart';
import '../data/inquiry_repository.dart';
import '../domain/inquiry.dart';

enum _Box { received, sent }

/// Inquiries inbox. Farmers see what buyers asked; everyone sees what they sent.
class InboxTab extends ConsumerStatefulWidget {
  const InboxTab({super.key});

  @override
  ConsumerState<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends ConsumerState<InboxTab> {
  _Box? _box;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final isFarmer = session is SignedIn && session.role == Role.farmer;
    final box = _box ?? (isFarmer ? _Box.received : _Box.sent);
    final async = box == _Box.received
        ? ref.watch(receivedInquiriesProvider)
        : ref.watch(sentInquiriesProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final names = {
      for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        x.id: x.nameIn(context),
    };
    final unread = ref.watch(newInquiryCountProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SharedTokens.space4,
        SharedTokens.space5,
        SharedTokens.space4,
        SharedTokens.space6,
      ),
      children: [
        SectionHeader(kicker: l10n.inboxKicker, title: l10n.inboxTitle),
        const SizedBox(height: SharedTokens.space3),
        if (isFarmer) ...[
          SegmentedButton<_Box>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _Box.received,
                label: Text(unread > 0 ? l10n.inboxReceivedCount(unread) : l10n.inboxReceived),
              ),
              ButtonSegment(value: _Box.sent, label: Text(l10n.inboxSent)),
            ],
            selected: {box},
            onSelectionChanged: (s) => setState(() => _box = s.first),
          ),
          const SizedBox(height: SharedTokens.space3),
        ],
        Text(l10n.inboxHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: SharedTokens.space3),
        ...async.when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            MessageView(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork),
          ],
          data: (list) => list.isEmpty
              ? [
                  MessageView(
                    icon: Icons.forum_outlined,
                    title: l10n.inboxEmptyTitle,
                    body: box == _Box.received ? l10n.inboxEmptyReceived : l10n.inboxEmptySent,
                  ),
                ]
              : [
                  for (final q in list) ...[
                    _InquiryCard(
                      key: Key('inq_${q.id}'),
                      inquiry: q,
                      received: box == _Box.received,
                      commodityName: names[q.commodityId] ?? q.commodityId,
                      now: now,
                    ),
                    const SizedBox(height: SharedTokens.space3),
                  ],
                ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final InquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (Color fill, Color on, IconData icon, String label) = switch (status) {
      InquiryStatus.newInquiry => (
        scheme.primary,
        scheme.onPrimary,
        Icons.mark_email_unread_outlined,
        l10n.inqNew,
      ),
      InquiryStatus.read => (c.primaryTint, scheme.onSurface, Icons.drafts_outlined, l10n.inqRead),
      InquiryStatus.closed => (c.confidenceLow, c.onConfidenceLow, Icons.check, l10n.inqClosed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: on),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: on)),
        ],
      ),
    );
  }
}

class _InquiryCard extends ConsumerWidget {
  const _InquiryCard({
    super.key,
    required this.inquiry,
    required this.received,
    required this.commodityName,
    required this.now,
  });
  final Inquiry inquiry;
  final bool received;
  final String commodityName;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final repo = ref.read(inquiryRepositoryProvider);
    final unread = received && inquiry.status == InquiryStatus.newInquiry;
    return PanelCard(
      accent: unread,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  received ? l10n.inqFrom(inquiry.buyerName) : l10n.inqAbout(commodityName),
                  style: t.titleMedium?.copyWith(fontWeight: unread ? FontWeight.w800 : null),
                ),
              ),
              _StatusPill(status: inquiry.status),
            ],
          ),
          Text('$commodityName · ${ageLabel(l10n, now, inquiry.createdAt)}', style: t.bodySmall),
          const SizedBox(height: SharedTokens.space2),
          Text(inquiry.message, style: t.bodyLarge),
          const SizedBox(height: SharedTokens.space3),
          if (received) ...[
            Row(
              children: [
                Icon(Icons.phone_android, size: 18, color: c.textMuted),
                const SizedBox(width: 6),
                Text(formatPhMobile(inquiry.buyerPhone), style: t.titleSmall),
              ],
            ),
            const SizedBox(height: SharedTokens.space2),
          ],
          Wrap(
            spacing: SharedTokens.space2,
            runSpacing: SharedTokens.space2,
            children: [
              if (received) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    if (unread) repo.setStatus(inquiry.id, InquiryStatus.read);
                    callNumber(inquiry.buyerPhone);
                  },
                  icon: const Icon(Icons.call),
                  label: Text(l10n.call),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (unread) repo.setStatus(inquiry.id, InquiryStatus.read);
                    textNumber(inquiry.buyerPhone);
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.text),
                ),
                if (unread)
                  TextButton(
                    key: Key('markRead_${inquiry.id}'),
                    onPressed: () => repo.setStatus(inquiry.id, InquiryStatus.read),
                    child: Text(l10n.markRead),
                  ),
              ],
              TextButton(
                onPressed: () => context.push(Routes.listing(inquiry.listingId)),
                child: Text(l10n.viewListing),
              ),
              if (inquiry.status != InquiryStatus.closed)
                TextButton(
                  onPressed: () => repo.setStatus(inquiry.id, InquiryStatus.closed),
                  child: Text(l10n.closeInquiry),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
