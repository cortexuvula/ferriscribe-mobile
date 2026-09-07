import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/patient_context.dart';
import 'package:ferriscribe_mobile/features/recording/patient_context_form.dart';

void main() {
  // Drives the REAL PatientContextForm (§5C contract), pushed over a base
  // route so it has a back button.
  Future<void> pumpForm(WidgetTester tester, {PatientContext? initial}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<PatientContext>(
                    builder: (_) => PatientContextForm(initial: initial),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Use context returns the typed context', (tester) async {
    PatientContext? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<PatientContext>(
                    MaterialPageRoute(
                      builder: (_) => const PatientContextForm(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Medications'),
      'Lisinopril',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Use context'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Use context'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.medications, ['Lisinopril']);
    // Copy contract: not "Saved to server".
    expect(find.text('Saved to server'), findsNothing);
  });

  testWidgets('dirty back confirms discard; keep editing preserves the form', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Allergies'),
      'Penicillin',
    );
    await tester.pump();
    // Dismiss the keyboard so the app-bar back button is tappable.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    // Form intact with the edit.
    expect(find.widgetWithText(TextField, 'Allergies'), findsOneWidget);
    expect(find.text('Penicillin'), findsAny);
  });

  testWidgets('clean back exits without confirmation', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    // Back on the base route.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('label and helper are both present, not hints alone (§5C)', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Allergies'), findsOneWidget);
    expect(find.textContaining('Leave blank if not provided'), findsOneWidget);
    // Blank allergies is "not provided", never "No known allergies".
    expect(find.textContaining('No known allergies'), findsNothing);
  });
}
