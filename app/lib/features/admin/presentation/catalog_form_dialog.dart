import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/domain/catalog_validation.dart';
import 'admin_labels.dart';

Future<void> showCatalogForm(BuildContext context, CatalogKind kind, {CatalogItem? existing}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CatalogFormDialog(kind: kind, existing: existing),
    );

class _CatalogFormDialog extends ConsumerStatefulWidget {
  const _CatalogFormDialog({required this.kind, this.existing});
  final CatalogKind kind;
  final CatalogItem? existing;

  @override
  ConsumerState<_CatalogFormDialog> createState() => _CatalogFormDialogState();
}

class _CatalogFormDialogState extends ConsumerState<_CatalogFormDialog> {
  late final _id = TextEditingController(text: widget.existing?.id ?? '');
  late final _name = TextEditingController(
    text: switch (widget.existing) {
      Commodity(:final nameFil) => nameFil,
      Market(:final name) => name,
      null => '',
    },
  );
  late final _nameEn = TextEditingController(
    text: widget.existing is Commodity ? (widget.existing as Commodity).nameEn : '',
  );
  late final _category = TextEditingController(
    text: widget.existing is Commodity ? (widget.existing as Commodity).category : '',
  );
  late String _unit = widget.existing is Commodity ? (widget.existing as Commodity).unit : 'kg';
  late String? _municipality = widget.existing is Market
      ? (widget.existing as Market).municipality
      : null;
  late String _type = widget.existing is Market
      ? (widget.existing as Market).type
      : 'public_market';
  late bool _active = widget.existing?.active ?? true;
  bool _idEdited = false;
  bool _saving = false;
  List<RowIssue> _issues = const [];
  String? _serverError;

  bool get _isNew => widget.existing == null;
  bool get _isCommodity => widget.kind == CatalogKind.commodities;

  @override
  void dispose() {
    for (final c in [_id, _name, _nameEn, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  CatalogItem _build() => _isCommodity
      ? Commodity(
          id: _id.text.trim(),
          nameFil: _name.text.trim(),
          nameEn: _nameEn.text.trim(),
          unit: _unit,
          category: _category.text.trim(),
          active: _active,
        )
      : Market(
          id: _id.text.trim(),
          name: _name.text.trim(),
          municipality: _municipality ?? '',
          type: _type,
          active: _active,
        );

  String? _err(String field) {
    final l10n = AppLocalizations.of(context);
    for (final i in _issues) {
      if (i.field == field) return issueText(l10n, i).split(': ').last;
    }
    return null;
  }

  Future<void> _save() async {
    final item = _build();
    final issues = CatalogValidation.item(item);
    setState(() {
      _issues = issues;
      _serverError = null;
    });
    if (issues.isNotEmpty) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(catalogRepositoryProvider).upsert(widget.kind, [item]);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } on CatalogWriteException catch (e) {
      setState(() {
        _saving = false;
        _serverError = e.rowErrors.isNotEmpty ? e.rowErrors.first.message : l10n.errGeneric;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _serverError = l10n.errGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isCommodity
        ? (_isNew ? l10n.addCommodity : l10n.editCommodity)
        : (_isNew ? l10n.addMarket : l10n.editMarket);
    const gap = SizedBox(height: SharedTokens.space4);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_serverError != null) ...[
                Text(
                  _serverError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                ),
                gap,
              ],
              TextField(
                key: const Key('formName'),
                controller: _name,
                autofocus: _isNew,
                decoration: InputDecoration(
                  labelText: _isCommodity ? l10n.fieldNameFil : l10n.fieldMarketName,
                  errorText: _err(_isCommodity ? 'nameFil' : 'name'),
                ),
                onChanged: (v) {
                  if (_isNew && !_idEdited) _id.text = slugify(v);
                },
              ),
              if (_isCommodity) ...[
                gap,
                TextField(
                  key: const Key('formNameEn'),
                  controller: _nameEn,
                  decoration: InputDecoration(
                    labelText: l10n.fieldNameEn,
                    errorText: _err('nameEn'),
                  ),
                ),
              ],
              gap,
              TextField(
                key: const Key('formId'),
                controller: _id,
                enabled: _isNew,
                decoration: InputDecoration(
                  labelText: l10n.fieldId,
                  helperText: _isNew ? l10n.fieldIdHelp : l10n.fieldIdLocked,
                  helperMaxLines: 2,
                  errorText: _err('id'),
                ),
                onChanged: (_) => _idEdited = true,
              ),
              gap,
              if (_isCommodity) ...[
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: InputDecoration(labelText: l10n.colUnit),
                  items: [
                    for (final u in AppConfig.units)
                      DropdownMenuItem(value: u, child: Text(unitLabel(l10n, u))),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? 'kg'),
                ),
                gap,
                TextField(
                  key: const Key('formCategory'),
                  controller: _category,
                  decoration: InputDecoration(
                    labelText: l10n.colCategory,
                    helperText: l10n.fieldCategoryHelp,
                    errorText: _err('category'),
                  ),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _municipality,
                  decoration: InputDecoration(
                    labelText: l10n.colMunicipality,
                    errorText: _err('municipality'),
                  ),
                  items: [
                    for (final m in AppConfig.municipalities)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setState(() => _municipality = v),
                ),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.colType),
                  items: [
                    for (final t in AppConfig.marketTypes)
                      DropdownMenuItem(value: t, child: Text(marketTypeLabel(l10n, t))),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'public_market'),
                ),
              ],
              const SizedBox(height: SharedTokens.space2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l10n.statusActive),
                subtitle: Text(l10n.activeHelp),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('formSave'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
