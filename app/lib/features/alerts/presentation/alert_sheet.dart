import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../../price_board/application/board_providers.dart';
import '../../price_board/domain/board_entry.dart';
import '../../reports/domain/price_report.dart';
import '../data/alert_repository.dart';
import '../domain/price_alert.dart';

Future<void> showAlertSheet(BuildContext context, {String? commodityId, String? marketId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AlertSheet(commodityId: commodityId, marketId: marketId),
    );

class _AlertSheet extends ConsumerStatefulWidget {
  const _AlertSheet({this.commodityId, this.marketId});
  final String? commodityId;
  final String? marketId;

  @override
  ConsumerState<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<_AlertSheet> {
  late String? _commodityId = widget.commodityId;
  late String? _marketId = widget.marketId;
  AlertDirection _direction = AlertDirection.above;
  final _threshold = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    final t = parsePrice(_threshold.text);
    final String? problem = _commodityId == null || _marketId == null
        ? l10n.reportErrPick
        : t == null
        ? l10n.reportErrInvalid
        : (ref.read(myAlertsProvider).value?.length ?? 0) >= maxAlertsPerUser
        ? l10n.alertsLimit(maxAlertsPerUser)
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (session is! SignedIn) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(alertRepositoryProvider)
          .create(
            uid: session.user.uid,
            commodityId: _commodityId!,
            marketId: _marketId!,
            threshold: t!,
            direction: _direction,
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.alertSaved)));
    } catch (_) {
      setState(() {
        _saving = false;
        _error = l10n.errGeneric;
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
    final markets = ref.watch(orderedMarketsProvider);
    _marketId ??= markets.isEmpty ? null : markets.first.id;
    BoardEntry? current;
    if (_commodityId != null) {
      for (final e
          in ref.watch(commodityBoardProvider(_commodityId!)).value?.entries ??
              const <BoardEntry>[]) {
        if (e.marketId == _marketId) current = e;
      }
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SharedTokens.space5,
        0,
        SharedTokens.space5,
        MediaQuery.viewInsetsOf(context).bottom + SharedTokens.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.newAlertTitle, style: t.titleLarge),
            const SizedBox(height: SharedTokens.space2),
            Text(l10n.newAlertHelp, style: t.bodySmall),
            const SizedBox(height: SharedTokens.space4),
            if (_error != null) ...[
              NoticeBanner(icon: Icons.error_outline, message: _error!, kind: NoticeKind.error),
              const SizedBox(height: SharedTokens.space3),
            ],
            DropdownButtonFormField<String>(
              key: const Key('alertCommodity'),
              initialValue: _commodityId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.fieldCommodity,
                prefixIcon: const Icon(Icons.eco_outlined),
              ),
              items: [
                for (final x in commodities)
                  DropdownMenuItem(value: x.id, child: Text(x.labelIn(context))),
              ],
              onChanged: (v) => setState(() => _commodityId = v),
            ),
            const SizedBox(height: SharedTokens.space3),
            DropdownButtonFormField<String>(
              key: const Key('alertMarket'),
              initialValue: _marketId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.fieldMarket,
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
              items: [
                for (final m in markets)
                  DropdownMenuItem(value: m.id, child: Text('${m.name} · ${m.municipality}')),
              ],
              onChanged: (v) => setState(() => _marketId = v),
            ),
            if (current != null) ...[
              const SizedBox(height: SharedTokens.space2),
              Text(l10n.currentMedian(peso(current.medianPrice)), style: t.bodyMedium),
            ],
            const SizedBox(height: SharedTokens.space3),
            SegmentedButton<AlertDirection>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AlertDirection.above,
                  icon: const Icon(Icons.arrow_upward),
                  label: Text(l10n.alertAbove),
                ),
                ButtonSegment(
                  value: AlertDirection.below,
                  icon: const Icon(Icons.arrow_downward),
                  label: Text(l10n.alertBelow),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: SharedTokens.space3),
            TextField(
              key: const Key('alertThreshold'),
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(labelText: l10n.alertThreshold, prefixText: '₱ '),
            ),
            const SizedBox(height: SharedTokens.space4),
            FilledButton.icon(
              key: const Key('alertSave'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.alertSave),
            ),
          ],
        ),
      ),
    );
  }
}
