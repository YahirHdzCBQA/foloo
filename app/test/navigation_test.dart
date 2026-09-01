import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> enterBasicCapture(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('loginEmailField')),
    'y.hernandez',
  );
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('profileScreen')), findsOneWidget);
  await tester.tap(find.byKey(const Key('profileContinueButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
  await tester.tap(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cardSection')), findsOneWidget);
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
  await tester.pumpAndSettle();
}

Future<void> selectDrawerDestination(
  WidgetTester tester,
  Key destination,
) async {
  await openDrawer(tester);
  await tester.tap(find.byKey(destination));
  await tester.pumpAndSettle();
}

Future<void> completeRequiredLead(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('nameField')), 'Ana');
  await tester.enterText(find.byKey(const Key('lastNameField')), 'López');
  await tester.enterText(find.byKey(const Key('companyField')), 'Estudio Uno');
  await tester.enterText(
    find.byKey(const Key('emailField')),
    'ana@example.com',
  );
  final partner = find.byKey(const Key('leadType-partner'));
  await tester.scrollUntilVisible(
    partner,
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(partner);
  await tester.tap(find.byKey(const Key('saveLeadButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drawer navigates to records and closes from the scrim', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);
    await openDrawer(tester);
    expect(find.text('Registros'), findsOneWidget);
    expect(find.text('Mis eventos'), findsOneWidget);
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logoutButton')), findsNothing);
    await selectDrawerDestination(tester, const Key('drawerRecords'));
    expect(find.byKey(const ValueKey('recordsScreen')), findsOneWidget);
    expect(find.text('Aún no hay registros'), findsOneWidget);

    await tester.tap(find.byKey(const Key('screenLogoButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSection')), findsOneWidget);

    await selectDrawerDestination(tester, const Key('drawerRecords'));
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('drawerLogoButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSection')), findsOneWidget);
  });

  testWidgets('drawer opens Mis eventos and supports create/edit navigation', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);
    await selectDrawerDestination(tester, const Key('drawerEvents'));
    expect(find.byKey(const ValueKey('eventsScreen')), findsOneWidget);
    expect(find.text('Mis eventos'), findsWidgets);
    expect(find.byKey(const Key('createEventButton')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('event-expo-alimentaria'))).height,
      62,
    );
    await tester.tap(find.byKey(const Key('event-expo-alimentaria')));
    await tester.pumpAndSettle();
    expect(find.text('Editar evento'), findsOneWidget);
    expect(find.byKey(const Key('editEventNameField')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeEventEditorButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eventsList')), findsOneWidget);
    await tester.tap(find.byKey(const Key('eventsBackButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSection')), findsOneWidget);
  });

  testWidgets('capture origin switches locally and reuses event dialog', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);

    expect(find.byKey(const Key('captureOriginSection')), findsOneWidget);
    expect(find.byKey(const Key('captureEventDropdown')), findsOneWidget);

    await tester.tap(find.byKey(const Key('captureOriginDirectTab')));
    await tester.pumpAndSettle();
    expect(
      find.text('Se guarda sin evento, en tu base general de leads.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('captureEventDropdown')), findsNothing);

    await tester.tap(find.byKey(const Key('captureOriginEventTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('captureEventDropdown')), findsOneWidget);
    await tester.tap(find.byKey(const Key('captureCreateEventButton')));
    await tester.pumpAndSettle();
    expect(find.text('Crear evento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('event creation dates open the Foloo calendar and are retained', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);

    await tester.tap(find.byKey(const Key('captureCreateEventButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('newEventNameField')),
      'Expo Fecha Editable',
    );
    await tester.tap(find.byKey(const Key('newEventStartDate')));
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    expect(dialog, findsOneWidget);
    final day = find.descendant(of: dialog, matching: find.text('13'));
    expect(day, findsWidgets);
    await tester.tap(day.last);
    await tester.pump();
    final pickerContext = tester.element(dialog);
    final okLabel = MaterialLocalizations.of(pickerContext).okButtonLabel;
    await tester.tap(find.text(okLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmCreateEventButton')));
    await tester.pumpAndSettle();

    await selectDrawerDestination(tester, const Key('drawerEvents'));
    await tester.tap(find.text('Expo Fecha Editable'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('editEventStartDate')),
        matching: find.textContaining('13'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('editEventEndDate')));
    await tester.pumpAndSettle();
    final editDialog = find.byType(DatePickerDialog);
    expect(editDialog, findsOneWidget);
    final endDay = find.descendant(of: editDialog, matching: find.text('16'));
    expect(endDay, findsWidgets);
    await tester.tap(endDay.last);
    await tester.pump();
    final editPickerContext = tester.element(find.byType(DatePickerDialog));
    final editOkLabel = MaterialLocalizations.of(editPickerContext)
        .okButtonLabel;
    await tester.tap(find.text(editOkLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveEventButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expo Fecha Editable'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('editEventEndDate')),
        matching: find.textContaining('16'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('saved lead appears in records and opens read-only detail', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);
    await completeRequiredLead(tester);
    expect(find.text('Lead guardado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('captureAnotherButton')));
    await tester.pumpAndSettle();
    await selectDrawerDestination(tester, const Key('drawerEvents'));
    await tester.tap(find.byKey(const Key('event-expo-alimentaria')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('eventLeadCount')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('eventPendingCount')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('closeEventEditorButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eventsBackButton')));
    await tester.pumpAndSettle();
    await selectDrawerDestination(tester, const Key('drawerRecords'));
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.textContaining('Estudio Uno'), findsOneWidget);
    expect(find.text('FOL-260812-001'), findsNothing);
    await tester.tap(find.text('Ana López'));
    await tester.pumpAndSettle();
    expect(find.text('Contacto'), findsOneWidget);
    expect(find.text('Fecha y hora'), findsOneWidget);
    expect(find.text('Origen'), findsOneWidget);
    expect(find.text('Capturó'), findsOneWidget);
    expect(find.text('FOL-260812-001'), findsNothing);
    expect(find.byKey(const Key('detailBackButton')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('appearance toggle is local and logout returns to login', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('appearanceSwitch')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('appDrawer')))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  });

  testWidgets('Basic capture excludes Pro and legacy controls', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await enterBasicCapture(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('relationshipSection')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Proveedor'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.textContaining('Siguiente paso'), findsNothing);
    expect(find.textContaining('Transcrip'), findsNothing);
    expect(find.textContaining('Correo enviado'), findsNothing);
    expect(find.textContaining('Copia Admin'), findsNothing);
  });
}
