import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/brand.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../application/board_providers.dart';

/// Header place switcher (as in One Vizcaya): "Prices in / All of Nueva Vizcaya ▾".
class ScopeButton extends ConsumerWidget {
  const ScopeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final scope = ref.watch(priceScopeProvider);
    final place = scope ?? l10n.scopeProvince;
    return Semantics(
      button: true,
      label: l10n.scopeSemantics(place),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('scopePicker'),
        borderRadius: BorderRadius.circular(SharedTokens.radiusSmall),
        onTap: () => showScopePicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TimbangEmblem(size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.scopeLabel.toUpperCase(), style: dataLabelStyle(context)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.1),
                          ),
                        ),
                        Icon(Icons.expand_more, color: c.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: the whole province first, then the 15 municipalities with their market count.
Future<void> showScopePicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(priceScopeProvider);
  final session = ref.read(sessionProvider);
  final town = session is SignedIn ? session.profile.municipality : null;
  final markets = (ref.read(marketsProvider).value ?? const []).where((m) => m.active).toList();
  int count(String m) => markets.where((x) => x.municipality == m).length;
  final towns = [...AppConfig.municipalities]
    ..sort((a, b) => a == town ? -1 : (b == town ? 1 : a.compareTo(b)));

  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;
      Widget tile({
        required String value,
        required String title,
        required String subtitle,
        required IconData icon,
        String? tag,
      }) {
        final selected = (value.isEmpty ? null : value) == current;
        return ListTile(
          key: Key('scope_${value.isEmpty ? 'province' : value}'),
          selected: selected,
          leading: Icon(icon, color: selected ? scheme.primary : null),
          title: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text(tag == null ? subtitle : '$subtitle · $tag'),
          trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
          onTap: () => Navigator.pop(ctx, value),
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(l10n.choosePlace, style: t.titleLarge),
              ),
              tile(
                value: '',
                title: l10n.scopeProvince,
                subtitle: l10n.scopeProvinceSub,
                icon: Icons.map_outlined,
              ),
              const Divider(height: 1),
              for (final m in towns)
                tile(
                  value: m,
                  title: m,
                  subtitle: l10n.townMarketsCount(count(m)),
                  icon: Icons.place_outlined,
                  tag: m == town ? l10n.ownTownTag : null,
                ),
            ],
          ),
        ),
      );
    },
  );
  if (chosen == null) return;
  await ref.read(priceScopeProvider.notifier).choose(chosen.isEmpty ? null : chosen);
  ref.read(selectedMarketIdProvider.notifier).clear();
}
