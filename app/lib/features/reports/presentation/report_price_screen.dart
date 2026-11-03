import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/source_tag.dart';
import '../../../shared/widgets/state_views.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../data/price_report_repository.dart';
import '../domain/price_report.dart';

/// "Mag-ulat ng presyo": any signed-in user. Reporters/admins count as verified;
/// everyone else is a community report (low confidence until matched).
class ReportPriceScreen extends ConsumerStatefulWidget {
  const ReportPriceScreen({super.key});

  @override
  ConsumerState<ReportPriceScreen> createState() => _ReportPriceScreenState();
}

class _ReportPriceScreenState extends ConsumerState<ReportPriceScreen> {
  final _price = TextEditingController();
  String? _commodityId;
  String? _marketId;
  bool _sending = false;
  String? _error;
  PriceSource? _sentAs;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  String _errorText(AppLocalizations l10n, SubmitError e) => switch (e) {
    SubmitError.rateLimited => l10n.reportErrRateLimited,
    SubmitError.duplicate => l10n.reportErrDuplicate,
    SubmitError.notFound => l10n.reportErrNotFound,
    SubmitError.notAllowed => l10n.reportErrNotAllowed,
    SubmitError.invalid => l10n.reportErrInvalid,
    SubmitError.network => l10n.errNetwork,
    SubmitError.generic => l10n.errGeneric,
  };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final price = parsePrice(_price.text);
    if (_commodityId == null || _marketId == null) {
      setState(() => _error = l10n.reportErrPick);
      return;
    }
    if (price == null) {
      setState(() => _error = l10n.reportErrInvalid);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final source = await ref
          .read(priceReportRepositoryProvider)
          .submit(commodityId: _commodityId!, marketId: _marketId!, price: price);
      setState(() {
        _sending = false;
        _sentAs = source;
      });
    } on SubmitFailure catch (f) {
      setState(() {
        _sending = false;
        _error = _errorText(l10n, f.error);
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = l10n.errGeneric;
      });
    }
  }

  void _another() => setState(() {
    _sentAs = null;
    _price.clear();
    _commodityId = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(l10n.reportTitle),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.prices),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, color: c.highlight),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _sentAs != null ? _Done(source: _sentAs!, onAnother: _another) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider);
    final role = session is SignedIn ? session.role : Role.farmer;
    final verified = role == Role.reporter || role == Role.admin;
    final myTown = session is SignedIn ? session.profile.municipality : null;
    final commodities = (ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        .where((x) => x.active)
        .toList();
    final markets =
        [...(ref.watch(marketsProvider).value ?? const <Market>[]).where((m) => m.active)]
          ..sort((a, b) {
            // Markets in the user's own town first.
            final at = a.municipality == myTown ? 0 : 1;
            final bt = b.municipality == myTown ? 0 : 1;
            return at != bt ? at - bt : a.name.compareTo(b.name);
          });
    Commodity? selected;
    for (final x in commodities) {
      if (x.id == _commodityId) selected = x;
    }
    final unit = selected == null ? '' : unitLabel(l10n, selected.unit);

    if (commodities.isEmpty || markets.isEmpty) {
      return MessageView(
        icon: Icons.inventory_2_outlined,
        title: l10n.catalogEmptyTitle,
        body:
            (ref.watch(sessionProvider) is SignedIn &&
                (ref.watch(sessionProvider) as SignedIn).isAdmin)
            ? l10n.catalogEmptyAdmin
            : l10n.reportNoCatalog,
        action:
            (ref.watch(sessionProvider) is SignedIn &&
                (ref.watch(sessionProvider) as SignedIn).isAdmin)
            ? FilledButton.icon(
                onPressed: () => context.go(Routes.adminCommodities),
                icon: const Icon(Icons.eco_outlined),
                label: Text(l10n.catalogEmptyAdminButton),
              )
            : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SharedTokens.space4),
      children: [
        SectionHeader(kicker: l10n.reportKicker, title: l10n.reportHeading),
        const SizedBox(height: SharedTokens.space3),
        NoticeBanner(
          icon: verified ? Icons.verified_user_outlined : Icons.groups_outlined,
          kind: NoticeKind.info,
          message: verified ? l10n.reportAsReporter : l10n.reportAsCommunity,
        ),
        const SizedBox(height: SharedTokens.space5),
        if (_error != null) ...[
          NoticeBanner(icon: Icons.error_outline, message: _error!, kind: NoticeKind.error),
          const SizedBox(height: SharedTokens.space4),
        ],
        DropdownButtonFormField<String>(
          key: const Key('reportCommodity'),
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
        const SizedBox(height: SharedTokens.space4),
        DropdownButtonFormField<String>(
          key: const Key('reportMarket'),
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
        const SizedBox(height: SharedTokens.space4),
        TextField(
          key: const Key('reportPrice'),
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            LengthLimitingTextInputFormatter(9),
          ],
          style: t.headlineSmall,
          decoration: InputDecoration(
            labelText: l10n.fieldPrice,
            prefixText: '₱ ',
            suffixText: unit.isEmpty ? null : '/ $unit',
            helperText: l10n.fieldPriceHelp,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: SharedTokens.space5),
        CtaButton(
          key: const Key('submitReport'),
          label: l10n.reportSubmit,
          icon: Icons.send,
          loading: _sending,
          onPressed: _submit,
        ),
        const SizedBox(height: SharedTokens.space4),
        Text(l10n.reportFinePrint, style: t.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.source, required this.onAnother});
  final PriceSource source;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(SharedTokens.space5),
      children: [
        const SizedBox(height: SharedTokens.space5),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: c.confidenceHigh, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 48, color: c.onConfidenceHigh),
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        Text(l10n.reportThanks, style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: SharedTokens.space3),
        Center(child: SourceTag(source: source)),
        const SizedBox(height: SharedTokens.space3),
        Text(
          source == PriceSource.community ? l10n.reportDoneCommunity : l10n.reportDoneReporter,
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SharedTokens.space6),
        FilledButton.icon(
          onPressed: () => context.go(Routes.prices),
          icon: const Icon(Icons.home_outlined),
          label: Text(l10n.backHome),
        ),
        const SizedBox(height: SharedTokens.space3),
        OutlinedButton.icon(
          key: const Key('reportAnother'),
          onPressed: onAnother,
          icon: const Icon(Icons.add),
          label: Text(l10n.reportAnother),
        ),
        const SizedBox(height: SharedTokens.space6),
        const Center(child: TimbangEmblem(size: 36)),
      ],
    );
  }
}
