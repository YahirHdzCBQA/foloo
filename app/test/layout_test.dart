import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';

void main() {
  testWidgets('keeps all sections in one usable scrollable viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FolooApp());

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);

    for (final key in const [
      Key('cardSection'),
      Key('dataSection'),
      Key('relationshipSection'),
      Key('noteSection'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(
        find.ancestor(of: find.byKey(key), matching: scrollView),
        findsOneWidget,
      );
    }

    final scrollRect = tester.getRect(scrollView);
    final saveRect = tester.getRect(find.byKey(const Key('saveLeadButton')));
    expect(scrollRect.height, greaterThan(500));
    expect(scrollRect.bottom, lessThanOrEqualTo(saveRect.top));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent,
      greaterThan(0),
    );

    expect(
      tester.getRect(find.byKey(const Key('cardSection'))).top,
      lessThan(844),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('noteSection')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('noteSection'))).top,
      lessThan(scrollRect.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the note reachable while the keyboard is visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const FolooApp());
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saveLeadButton')), findsNothing);

    final scrollView = find.byType(SingleChildScrollView);
    expect(tester.getRect(scrollView).height, greaterThan(250));

    final noteField = find.byKey(const Key('noteField'));
    await tester.scrollUntilVisible(
      noteField,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(noteField);
    await tester.pump();

    expect(
      tester.getRect(noteField).top,
      lessThan(tester.getRect(scrollView).bottom),
    );
    expect(tester.takeException(), isNull);
  });
}
