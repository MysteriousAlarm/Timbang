import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../reports/data/price_report_repository.dart';
import '../../reports/domain/official_csv.dart';
import '../../reports/domain/price_report.dart';
import 'admin_labels.dart';

/// Admin: enter or correct ONE official price by hand (no file needed, works on a phone).
/// Uses the same server-side import, so it is validated and audited the same way.
Future<void> showOfficialPriceDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _OfficialPriceDialog());

class _OfficialPriceDialog extends ConsumerStatefulWidget {
  const _OfficialPriceDialog();

  @override
  ConsumerState<_OfficialPriceDialog> createState() => _OfficialPriceDialogState();
}

class _OfficialPriceDialogState extends ConsumerState<_OfficialPriceDialog> {
  String? _commodityId;
  String? _marketId;
  DateTime _date = DateTime.now();
  final _price = TextEditingController();
  final _note = TextEditingController(text: 'DA / NVAT');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final price = parsePrice(_price.text);
    final note = _note.text.trim();
    final String? problem = _commodityId == null || _marketId == null
        ? l10n.reportErrPick
        : price == null
        ? l10n.reportErrInvalid
        : note.length < 2
        ? l10n.officialSourceHelp
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(priceReportRepositoryProvider)
          .importOfficial(
            sourceNote: note,
            rows: [
              OfficialRow(
                line: 1,
                commodityId: _commodityId!,
                marketId: _marketId!,
                price: price,
                date: DateFormat('yyyy-MM-dd').format(_date),
              ),
            ],
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.officialPriceSaved)));
    } on SubmitFailure catch (f) {
      setState(() {
        _saving = false;
        _error = f.rowErrors.isNotEmpty ? f.rowErrors.first.message : l10n.errGeneric;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = l10n.errNetwork;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final commodities = (ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        .where((x) => x.active)
        .toList();
    final markets = (ref.watch(marketsProvider).value ?? const <Market>[])
        .where((x) => x.active)
        .toList();
    Commodity? selected;
    for (final x in commodities) {
      if (x.id == _commodityId) selected = x;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    const gap = SizedBox(height: SharedTokens.space3);
    return AlertDialog(
      title: Text(l10n.addOfficialPrice),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addOfficialPriceHelp, style: t.bodySmall),
              gap,
              if (_error != null) ...[
                NoticeBanner(icon: Icons.error_outline, message: _error!, kind: NoticeKind.error),
                gap,
              ],
              DropdownButtonFormField<String>(
                key: const Key('opCommodity'),
                initialValue: _commodityId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldCommodity),
                items: [
                  for (final x in commodities)
                    DropdownMenuItem(value: x.id, child: Text('${x.nameFil} (${x.nameEn})')),
                ],
                onChanged: (v) => setState(() => _commodityId = v),
              ),
              gap,
              DropdownButtonFormField<String>(
                key: const Key('opMarket'),
                initialValue: _marketId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldMarket),
                items: [
                  for (final m in markets)
                    DropdownMenuItem(value: m.id, child: Text('${m.name} · ${m.municipality}')),
                ],
                onChanged: (v) => setState(() => _marketId = v),
              ),
              gap,
              TextField(
                key: const Key('opPrice'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: l10n.fieldPrice,
                  prefixText: '₱ ',
                  suffixText: selected == null ? null : '/ ${unitShort(l10n, selected.unit)}',
                ),
              ),
              gap,
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.fieldObservedDate,
                    prefixIcon: const Icon(Icons.event),
                  ),
                  child: Text(DateFormat.yMMMMd(locale).format(_date)),
                ),
              ),
              gap,
              TextField(
                key: const Key('opSource'),
                controller: _note,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.officialSourceLabel,
                  helperText: l10n.officialSourceHelp,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('opSave'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
