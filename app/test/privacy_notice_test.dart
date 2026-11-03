import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/privacy/presentation/privacy_notice_screen.dart';

import 'fakes.dart';

void main() {
  testWidgets('agreeing requires scrolling to the end and ticking the box', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showPrivacyNotice(context),
            child: const Text('open'),
          ),
        ),
        theme: harvestEarthTheme,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    CheckboxListTile box() =>
        tester.widget<CheckboxListTile>(find.byKey(const Key('privacyCheck')));
    FilledButton agree() => tester.widget<FilledButton>(find.byKey(const Key('privacyAgree')));
    expect(box().onChanged, isNull, reason: 'locked before reading');
    expect(agree().onPressed, isNull);
    expect(find.textContaining('Mag-scroll hanggang dulo'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('privacyEnd')),
      find.byKey(const Key('privacyScroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(box().onChanged, isNotNull);
    expect(agree().onPressed, isNull, reason: 'still needs the tick');

    await tester.tap(find.byKey(const Key('privacyCheck')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacyAgree')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
