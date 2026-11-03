import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/source_tag.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../moderation/presentation/flag_sheet.dart';
import '../../price_board/domain/board_entry.dart';
import '../data/admin_repository.dart';
import 'admin_labels.dart';
import 'admin_shell.dart';

/// Ask for a reason (stored in the audit log) before a moderation action.
Future<String?> askReason(BuildContext context, String title) async {
  final l10n = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        maxLength: 200,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.reasonLabel),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
      ],
    ),
  );
  final r = ctrl.text.trim();
  return ok == true && r.length >= 3 ? r : null;
}

class AdminModerationPage extends ConsumerWidget {
  const AdminModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final repo = ref.read(adminRepositoryProvider);
    final abuse = ref.watch(openAbuseProvider);
    final outliers = ref.watch(outlierReportsProvider);
    final commodities = {
      for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[]) x.id: x.nameFil,
    };
    final markets = {
      for (final x in ref.watch(marketsProvider).value ?? const <Market>[]) x.id: x.name,
    };
    final fmt = DateFormat('MMM d, h:mm a', Localizations.localeOf(context).toLanguageTag());
    final messenger = ScaffoldMessenger.of(context);

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
        messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('${l10n.errGeneric} ($e)')));
      }
    }

    String targetLabel(AbuseReport a) {
      if (a.targetType == 'price_board') {
        final parts = a.targetId.split('_');
        return '${l10n.flagPriceTarget}: ${commodities[parts.first] ?? parts.first} · ${markets[parts.length > 1 ? parts[1] : ''] ?? ''}';
      }
      return '${l10n.flagListingTarget}: ${a.targetId}';
    }

    return AdminPage(
      kicker: l10n.adminSafetyKicker,
      title: l10n.adminModeration,
      description: l10n.adminModerationDesc,
      children: [
        SectionHeader(kicker: l10n.abuseKicker, title: l10n.abuseTitle),
        const SizedBox(height: SharedTokens.space3),
        ...abuse.when(
          loading: () => [const LinearProgressIndicator()],
          error: (_, _) => [Text(l10n.errNetwork)],
          data: (list) => list.isEmpty
              ? [PanelCard(child: Text(l10n.abuseEmpty, style: t.bodyMedium))]
              : [
                  for (final a in list) ...[
                    PanelCard(
                      accent: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(abuseReasonLabel(l10n, a.reason), style: t.titleMedium),
                          Text(
                            '${targetLabel(a)} · ${fmt.format(a.createdAt)}',
                            style: t.bodySmall,
                          ),
                          if ((a.note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('“${a.note}”', style: t.bodyMedium),
                          ],
                          const SizedBox(height: SharedTokens.space2),
                          Wrap(
                            spacing: SharedTokens.space2,
                            runSpacing: SharedTokens.space2,
                            children: [
                              if (a.targetType == 'listing')
                                FilledButton.icon(
                                  onPressed: () async {
                                    final r = await askReason(context, l10n.removeListing);
                                    if (r == null) return;
                                    await run(() async {
                                      await repo.removeListing(a.targetId, r);
                                      await repo.resolveAbuse(a.id, resolved: true, note: r);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(l10n.removeListingAndResolve),
                                ),
                              OutlinedButton(
                                onPressed: () => run(() => repo.resolveAbuse(a.id, resolved: true)),
                                child: Text(l10n.markResolved),
                              ),
                              TextButton(
                                onPressed: () =>
                                    run(() => repo.resolveAbuse(a.id, resolved: false)),
                                child: Text(l10n.dismiss),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SharedTokens.space2),
                  ],
                ],
        ),
        const SizedBox(height: SharedTokens.space6),
        SectionHeader(kicker: l10n.outliersKicker, title: l10n.outliersTitle),
        const SizedBox(height: SharedTokens.space2),
        Text(l10n.outliersHelp, style: t.bodySmall),
        const SizedBox(height: SharedTokens.space3),
        ...outliers.when(
          loading: () => [const LinearProgressIndicator()],
          error: (_, _) => [Text(l10n.errNetwork)],
          data: (list) => list.isEmpty
              ? [PanelCard(child: Text(l10n.outliersEmpty, style: t.bodyMedium))]
              : [
                  for (final r in list) ...[
                    PanelCard(
                      child: Wrap(
                        spacing: SharedTokens.space3,
                        runSpacing: SharedTokens.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${commodities[r.commodityId] ?? r.commodityId} · ${markets[r.marketId] ?? r.marketId}',
                                style: t.titleSmall,
                              ),
                              Text(
                                '${peso(r.price)} / ${unitShort(l10n, r.unit)} · ${fmt.format(r.timestamp)}',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                          SourceTag(source: r.source, compact: true),
                          Wrap(
                            spacing: SharedTokens.space2,
                            children: [
                              FilledButton(
                                onPressed: () async {
                                  final why = await askReason(context, l10n.rejectReport);
                                  if (why != null) {
                                    await run(
                                      () => repo.moderateReport(r.id, reject: true, reason: why),
                                    );
                                  }
                                },
                                child: Text(l10n.rejectReport),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final why = await askReason(context, l10n.restoreReport);
                                  if (why != null) {
                                    await run(
                                      () => repo.moderateReport(r.id, reject: false, reason: why),
                                    );
                                  }
                                },
                                child: Text(l10n.restoreReport),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SharedTokens.space2),
                  ],
                ],
        ),
      ],
    );
  }
}
