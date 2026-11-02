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
import '../../catalog/domain/catalog_item.dart';
import '../../reports/data/price_report_repository.dart';
import '../../reports/domain/official_csv.dart';

Future<void> showOfficialImportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _OfficialImportDialog());

class _OfficialImportDialog extends ConsumerStatefulWidget {
  const _OfficialImportDialog();

  @override
  ConsumerState<_OfficialImportDialog> createState() => _OfficialImportDialogState();
}

class _OfficialImportDialogState extends ConsumerState<_OfficialImportDialog> {
  final _note = TextEditingController();
  final _paste = TextEditingController();
  OfficialImport? _result;
  String? _fileName;
  bool _importing = false;
  List<String> _serverErrors = const [];

  @override
  void dispose() {
    _note.dispose();
    _paste.dispose();
    super.dispose();
  }

  void _parse(String text, {String? fileName}) {
    final commodityIds = {
      for (final x in ref.read(commoditiesProvider).value ?? const <Commodity>[])
        if (x.active) x.id,
    };
    final marketIds = {
      for (final x in ref.read(marketsProvider).value ?? const <Market>[])
        if (x.active) x.id,
    };
    setState(() {
      _result = parseOfficialCsv(text, commodityIds: commodityIds, marketIds: marketIds);
      _fileName = fileName;
      _serverErrors = const [];
    });
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (picked.isEmpty) return;
    final bytes = await picked.first.readAsBytes();
    _parse(utf8.decode(bytes, allowMalformed: true), fileName: picked.first.name);
  }

  bool get _noteOk => _note.text.trim().length >= 2 && _note.text.trim().length <= 80;

  Future<void> _import() async {
    final r = _result;
    if (r == null || !r.canImport || !_noteOk) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final n = await ref
          .read(priceReportRepositoryProvider)
          .importOfficial(sourceNote: _note.text.trim(), rows: r.rows);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importedPrices(n))));
    } on SubmitFailure catch (f) {
      setState(() {
        _importing = false;
        _serverErrors = f.rowErrors.isEmpty
            ? [l10n.errGeneric]
            : [for (final e in f.rowErrors) l10n.lineError(e.row + 1, e.message)];
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
    final c = TimbangColors.of(context);
    final r = _result;
    final errors = [
      for (final h in r?.headerIssues ?? const <String>[])
        l10n.headerError('$h: ${l10n.issueMissingColumn}'),
      for (final row in r?.rows ?? const <OfficialRow>[])
        for (final f in row.issues) l10n.lineError(row.line, '$f: ${l10n.officialFieldInvalid}'),
    ];
    return AlertDialog(
      title: Text(l10n.importOfficialPrices),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.officialImportHelp(AppConfig.officialImportMaxRows), style: t.bodyMedium),
              const SizedBox(height: SharedTokens.space4),
              TextField(
                key: const Key('officialSource'),
                controller: _note,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.officialSourceLabel,
                  helperText: l10n.officialSourceHelp,
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: SharedTokens.space3),
              Container(
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
                        Expanded(child: Text(l10n.csvTemplate.toUpperCase(), style: t.labelSmall)),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: officialCsvTemplate));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(l10n.copied)));
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(l10n.copy),
                        ),
                      ],
                    ),
                    SelectableText(
                      officialCsvTemplate.trim(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                    const SizedBox(height: SharedTokens.space2),
                    Text(l10n.officialCsvColumns, style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: SharedTokens.space4),
              Wrap(
                spacing: SharedTokens.space3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.chooseCsvFile),
                  ),
                  if (_fileName != null) Text(_fileName!, style: t.titleSmall),
                ],
              ),
              const SizedBox(height: SharedTokens.space3),
              TextField(
                key: const Key('officialPaste'),
                controller: _paste,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(labelText: l10n.orPasteCsv, alignLabelWithHint: true),
                onChanged: _parse,
              ),
              if (r != null) ...[
                const SizedBox(height: SharedTokens.space4),
                NoticeBanner(
                  icon: r.canImport ? Icons.check_circle_outline : Icons.error_outline,
                  kind: r.canImport ? NoticeKind.info : NoticeKind.notice,
                  message: r.tooMany
                      ? l10n.importTooMany(AppConfig.officialImportMaxRows)
                      : r.rows.isEmpty && r.headerIssues.isEmpty
                      ? l10n.importNoRows
                      : l10n.importSummary(r.rows.where((x) => x.ok).length, r.errorCount),
                ),
                const SizedBox(height: SharedTokens.space2),
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
                if (errors.length > 12)
                  Text(l10n.moreErrors(errors.length - 12), style: t.bodySmall),
              ],
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
          key: const Key('confirmOfficialImport'),
          onPressed: (r?.canImport ?? false) && _noteOk && !_importing ? _import : null,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(l10n.importRows(r?.rows.length ?? 0)),
        ),
      ],
    );
  }
}
