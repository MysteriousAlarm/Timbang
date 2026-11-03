import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/forest_gold_theme.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/shared/models/confidence.dart';
import 'package:timbang/shared/widgets/confidence_chip.dart';

import 'fakes.dart';

void main() {
  for (final (name, theme) in [
    ('Harvest Earth', harvestEarthTheme),
    ('Forest and Gold', forestGoldTheme),
  ]) {
    testWidgets('chips show icon + Filipino word ($name)', (tester) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [
              ConfidenceChip(confidence: Confidence.high),
              ConfidenceChip(confidence: Confidence.medium),
              ConfidenceChip(confidence: Confidence.low),
            ],
          ),
          theme: theme,
        ),
      );
      expect(find.text('Mataas'), findsOneWidget);
      expect(find.text('Katamtaman'), findsOneWidget);
      expect(find.text('Mababa'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(3));
      expect(find.bySemanticsLabel('Kumpiyansa: Mataas'), findsOneWidget);
    });
  }
}
