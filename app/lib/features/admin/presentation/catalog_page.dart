import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import 'admin_labels.dart';
import 'admin_shell.dart';
import 'catalog_form_dialog.dart';
import 'csv_import_dialog.dart';

enum _StatusFilter { all, active, inactive }

/// Commodities or markets: searchable table, add/edit, CSV import, demo cleanup.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, required this.kind});
  final CatalogKind kind;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;

  bool _matches(CatalogItem i) {
    if (_filter == _StatusFilter.active && !i.active) return false;
    if (_filter == _StatusFilter.inactive && i.active) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final hay = switch (i) {
      Commodity() => '${i.id} ${i.nameFil} ${i.nameEn} ${i.category}',
      Market() => '${i.id} ${i.name} ${i.municipality}',
    };
    return hay.toLowerCase().contains(q);
  }

  Future<void> _clearDemo(int count) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearDemoTitle),
        content: Text(l10n.clearDemoBody(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.clearDemo)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await ref.read(catalogRepositoryProvider).clearDemo(widget.kind);
      messenger.showSnackBar(SnackBar(content: Text(l10n.clearedDemo(n))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(catalogItemsProvider(widget.kind));
    final items = async.value ?? const <CatalogItem>[];
    final demo = items.where((i) => i.isDemo).length;
    final shown = items.where(_matches).toList();
    final isCommodities = widget.kind == CatalogKind.commodities;
    final c = TimbangColors.of(context);

    return AdminPage(
      kicker: l10n.adminCatalogKicker,
      title: kindTitle(l10n, widget.kind),
      description: isCommodities ? l10n.commoditiesDesc : l10n.marketsDesc,
      actions: [
        OutlinedButton.icon(
          key: const Key('importCsv'),
          onPressed: () => showCsvImportDialog(context, widget.kind),
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.importCsv),
        ),
        FilledButton.icon(
          key: const Key('addItem'),
          style: FilledButton.styleFrom(backgroundColor: c.cta, foregroundColor: c.onCta),
          onPressed: () => showCatalogForm(context, widget.kind),
          icon: const Icon(Icons.add),
          label: Text(isCommodities ? l10n.addCommodity : l10n.addMarket),
        ),
      ],
      children: [
        if (demo > 0) ...[
          NoticeBanner(
            icon: Icons.science_outlined,
            message: l10n.demoDataBanner(demo),
            action: TextButton(
              key: const Key('clearDemo'),
              onPressed: () => _clearDemo(demo),
              child: Text(l10n.clearDemo),
            ),
          ),
          const SizedBox(height: SharedTokens.space4),
        ],
        Wrap(
          spacing: SharedTokens.space3,
          runSpacing: SharedTokens.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                key: const Key('catalogSearch'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchHint,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            SegmentedButton<_StatusFilter>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _StatusFilter.all, label: Text(l10n.filterAll)),
                ButtonSegment(value: _StatusFilter.active, label: Text(l10n.statusActive)),
                ButtonSegment(value: _StatusFilter.inactive, label: Text(l10n.statusInactive)),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ],
        ),
        const SizedBox(height: SharedTokens.space4),
        PanelCard(
          padding: EdgeInsets.zero,
          child: async.isLoading && !async.hasValue
              ? const Padding(
                  padding: EdgeInsets.all(SharedTokens.space6),
                  child: Center(child: CircularProgressIndicator()),
                )
              : async.hasError
              ? MessageView(icon: Icons.cloud_off, title: l10n.errGeneric, body: l10n.errNetwork)
              : shown.isEmpty
              ? MessageView(
                  icon: isCommodities ? Icons.eco_outlined : Icons.storefront_outlined,
                  title: items.isEmpty ? l10n.catalogEmptyTitle : l10n.noMatches,
                  body: items.isEmpty ? l10n.catalogEmptyBody : '',
                )
              : _CatalogTable(kind: widget.kind, items: shown),
        ),
        const SizedBox(height: SharedTokens.space3),
        Text(
          l10n.showingCount(shown.length, items.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CatalogTable extends StatelessWidget {
  const _CatalogTable({required this.kind, required this.items});
  final CatalogKind kind;
  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final columns = switch (kind) {
      CatalogKind.commodities => [l10n.colName, l10n.colUnit, l10n.colCategory, l10n.colStatus, ''],
      CatalogKind.markets => [l10n.colName, l10n.colMunicipality, l10n.colType, l10n.colStatus, ''],
    };

    DataRow row(CatalogItem i) {
      final (String title, String sub, String a, String b) = switch (i) {
        Commodity() => (i.nameFil, '${i.nameEn} · ${i.id}', unitLabel(l10n, i.unit), i.category),
        Market() => (i.name, i.id, i.municipality, marketTypeLabel(l10n, i.type)),
      };
      return DataRow(
        cells: [
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    if (sub.isNotEmpty) Text(sub, style: t.bodySmall?.copyWith(color: c.textMuted)),
                  ],
                ),
                if (i.isDemo) ...[const SizedBox(width: SharedTokens.space2), const _DemoTag()],
              ],
            ),
          ),
          DataCell(Text(a)),
          DataCell(Text(b)),
          DataCell(_StatusPill(active: i.active)),
          DataCell(
            IconButton(
              tooltip: l10n.editProfile,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showCatalogForm(context, kind, existing: i),
            ),
          ),
        ],
      );
    }

    // Phones: one card per item instead of a wide table.
    Widget card(CatalogItem i) {
      final (String title, String sub, String a, String b) = switch (i) {
        Commodity() => (i.nameFil, '${i.nameEn} · ${i.id}', unitLabel(l10n, i.unit), i.category),
        Market() => (i.name, i.id, i.municipality, marketTypeLabel(l10n, i.type)),
      };
      return InkWell(
        key: Key('item_${i.id}'),
        onTap: () => showCatalogForm(context, kind, existing: i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SharedTokens.space4,
            SharedTokens.space3,
            SharedTokens.space2,
            SharedTokens.space3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    Text(sub, style: t.bodySmall?.copyWith(color: c.textMuted)),
                    Text('$a · $b', style: t.bodySmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _StatusPill(active: i.active),
                        if (i.isDemo) const _DemoTag(),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: c.textMuted),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 600
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var k = 0; k < items.length; k++) ...[
                  if (k > 0) const Divider(),
                  card(items[k]),
                ],
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: DataTable(
                  columns: [for (final col in columns) DataColumn(label: Text(col.toUpperCase()))],
                  rows: [for (final i in items) row(i)],
                ),
              ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final fill = active ? c.confidenceHigh : c.confidenceLow;
    final on = active ? c.onConfidenceHigh : c.onConfidenceLow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle : Icons.pause_circle, size: 16, color: on),
          const SizedBox(width: 4),
          Text(
            active ? l10n.statusActive : l10n.statusInactive,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: on),
          ),
        ],
      ),
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: SharedTokens.notice,
      border: Border.all(color: SharedTokens.noticeRule),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'DEMO',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: SharedTokens.onNotice),
    ),
  );
}
