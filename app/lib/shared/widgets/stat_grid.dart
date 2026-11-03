import 'package:flutter/material.dart';

import '../../core/theme/timbang_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One figure in a [StatGrid].
class Stat {
  const Stat({required this.label, required this.value, this.note, this.onTap, this.key});
  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;
  final Key? key;
}

/// Figures in one ruled panel, like the summary box of a printed report.
/// Phones: one row per figure (label left, number right). Wider: columns split by rules.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats, this.maxColumns = 4});

  final List<Stat> stats;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth < 520
            ? 1
            : (box.maxWidth / 220).floor().clamp(2, maxColumns).clamp(1, stats.length);
        final rows = <List<Stat>>[
          for (var i = 0; i < stats.length; i += cols)
            stats.sublist(i, (i + cols).clamp(0, stats.length)),
        ];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SharedTokens.radiusSmall),
            side: BorderSide(color: c.border),
          ),
          child: Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) Divider(height: 1, color: c.border),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cols; i++) ...[
                        if (i > 0) VerticalDivider(width: 1, color: c.border),
                        Expanded(
                          child: i < rows[r].length
                              ? _Cell(stat: rows[r][i], inline: cols == 1)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.stat, required this.inline});
  final Stat stat;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final label = Text(stat.label, style: t.labelMedium?.copyWith(color: c.textMuted));
    final value = Text(stat.value, style: priceStyle(context, 26));
    final note = stat.note == null ? null : Text(stat.note!, style: t.bodySmall);
    final body = inline
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, ?note],
                ),
              ),
              const SizedBox(width: SharedTokens.space3),
              value,
              if (stat.onTap != null) Icon(Icons.chevron_right, color: c.textMuted),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: label),
                  if (stat.onTap != null) Icon(Icons.chevron_right, size: 20, color: c.textMuted),
                ],
              ),
              const SizedBox(height: SharedTokens.space1),
              value,
              if (note != null) ...[const SizedBox(height: 2), note],
            ],
          );
    return InkWell(
      key: stat.key,
      onTap: stat.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SharedTokens.space4,
          vertical: SharedTokens.space3,
        ),
        child: body,
      ),
    );
  }
}
