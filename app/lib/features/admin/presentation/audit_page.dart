import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/admin_repository.dart';
import 'admin_shell.dart';

/// Read-only audit trail of sensitive actions (written by Cloud Functions only).
class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final async = ref.watch(auditProvider);
    final fmt = DateFormat('MMM d, y h:mm a', Localizations.localeOf(context).toLanguageTag());
    return AdminPage(
      kicker: l10n.adminSafetyKicker,
      title: l10n.adminAudit,
      description: l10n.adminAuditDesc,
      children: [
        PanelCard(
          padding: EdgeInsets.zero,
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                MessageView(icon: Icons.cloud_off, title: l10n.errGeneric, body: l10n.errNetwork),
            data: (list) => list.isEmpty
                ? MessageView(icon: Icons.receipt_long_outlined, title: l10n.auditEmpty, body: '')
                : LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: box.maxWidth),
                        child: DataTable(
                          columnSpacing: 24,
                          columns: [
                            for (final h in [
                              l10n.colTime,
                              l10n.colAction,
                              l10n.colTarget,
                              l10n.colDetail,
                              l10n.colActor,
                            ])
                              DataColumn(label: Text(h.toUpperCase())),
                          ],
                          rows: [
                            for (final e in list)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      fmt.format(e.timestamp),
                                      style: t.bodySmall?.copyWith(color: t.bodyMedium?.color),
                                    ),
                                  ),
                                  DataCell(Text(e.action, style: t.titleSmall)),
                                  DataCell(
                                    Text(
                                      e.targetPath,
                                      style: t.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: t.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: Text(e.detail, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      e.actorId.length > 10
                                          ? '${e.actorId.substring(0, 10)}…'
                                          : e.actorId,
                                      style: t.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: t.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: SharedTokens.space2),
        Text(l10n.auditFootnote, style: t.bodySmall),
      ],
    );
  }
}
