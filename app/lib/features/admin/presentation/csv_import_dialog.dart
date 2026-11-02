import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_csv.dart';
import '../../catalog/domain/catalog_item.dart';
import 'admin_labels.dart';

Future<void> showCsvImportDialog(BuildContext context, CatalogKind kind) => showDialog<void>(
  context: context,
  builder: (_) => _CsvImportDialog(kind: kind),
);

class _CsvImportDialog extends ConsumerStatefulWidget {
  const _CsvImportDialog({required this.kind});
  final CatalogKind kind;

  @override
  ConsumerState<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<_CsvImportDialog> {
  final _paste = TextEditingController();
  CsvImport? _result;
  String? _fileName;
  bool _importing = false;
  List<String> _serverErrors = const [];

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _parse(String text, {String? fileName}) => setState(() {
    _result = parseCatalogCsv(widget.kind, text);
    _fileName = fileName;
    _serverErrors = const [];
  });

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (picked.isEmpty) return;
    final file = picked.first;
    final bytes = await file.readAsBytes();
    _parse(utf8.decode(bytes, allowMalformed: true), fileName: file.name);
  }

  Future<void> _import() async {
    final r = _result;
    if (r == null || !r.canImport) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final n = await ref.read(catalogRepositoryProvider).upsert(widget.kind, r.items);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importedCount(n))));
    } on CatalogWriteException catch (e) {
      setState(() {
        _importing = false;
        _serverErrors = e.rowErrors.isEmpty
            ? [l10n.errGeneric]
            : [for (final x in e.rowErrors) l10n.lineError(x.row + 1, x.message)];
      });
    } catch (_) {
      setState(() {
        _importing = false;
        _serverErrors = [l10n.errGeneric];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final r = _result;
    return AlertDialog(
      title: Text(l10n.importTitle(kindTitle(l10n, widget.kind))),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.importHelp(AppConfig.catalogMaxItemsPerImport), style: t.bodyMedium),
              const SizedBox(height: SharedTokens.space4),
              _Template(kind: widget.kind),
              const SizedBox(height: SharedTokens.space4),
              Wrap(
                spacing: SharedTokens.space3,
                runSpacing: SharedTokens.space3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('pickCsv'),
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.chooseCsvFile),
                  ),
                  if (_fileName != null) Text(_fileName!, style: t.titleSmall),
                ],
              ),
              const SizedBox(height: SharedTokens.space3),
              TextField(
                key: const Key('pasteCsv'),
                controller: _paste,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(labelText: l10n.orPasteCsv, alignLabelWithHint: true),
                onChanged: (v) => _parse(v),
              ),
              if (r != null) ...[const SizedBox(height: SharedTokens.space4), _Summary(result: r)],
              for (final e in _serverErrors) ...[
                const SizedBox(height: SharedTokens.space2),
                NoticeBanner(icon: Icons.error_outline, message: e, kind: NoticeKind.error),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton.icon(
          key: const Key('confirmImport'),
          onPressed: (r?.canImport ?? false) && !_importing ? _import : null,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(l10n.importRows(r?.rows.length ?? 0)),
        ),
      ],
    );
  }
}

class _Template extends StatelessWidget {
  const _Template({required this.kind});
  final CatalogKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final text = csvTemplate(kind);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.csvTemplate.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.copy),
              ),
            ],
          ),
          SelectableText(
            text.trim(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          const SizedBox(height: SharedTokens.space2),
          Text(
            kind == CatalogKind.commodities ? l10n.csvAllowedCommodity : l10n.csvAllowedMarket,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});
  final CsvImport result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final r = result;
    final valid = r.rows.where((x) => x.ok).length;
    final errors = [
      for (final i in r.headerIssues) l10n.headerError(issueText(l10n, i)),
      for (final row in r.rows)
        for (final i in row.issues) l10n.lineError(row.line, issueText(l10n, i)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBanner(
          icon: r.canImport ? Icons.check_circle_outline : Icons.error_outline,
          kind: r.canImport ? NoticeKind.info : NoticeKind.notice,
          message: r.tooMany
              ? l10n.importTooMany(AppConfig.catalogMaxItemsPerImport)
              : r.rows.isEmpty && r.headerIssues.isEmpty
              ? l10n.importNoRows
              : l10n.importSummary(valid, r.errorCount),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: SharedTokens.space3),
          for (final e in errors.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e, style: t.bodyMedium)),
                ],
              ),
            ),
          if (errors.length > 12) Text(l10n.moreErrors(errors.length - 12), style: t.bodySmall),
        ],
        if (valid > 0) ...[
          const SizedBox(height: SharedTokens.space3),
          Text(l10n.preview.toUpperCase(), style: t.labelSmall),
          const SizedBox(height: SharedTokens.space1),
          for (final row in r.rows.where((x) => x.ok).take(6))
            Text('• ${row.item!.id} — ${row.item!.displayName}', style: t.bodyMedium),
        ],
      ],
    );
  }
}
