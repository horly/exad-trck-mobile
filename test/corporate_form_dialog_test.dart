import 'package:exad_tracking_mobile/shared/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps corporate form actions visible on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (context) => CorporateFormDialog(
                    title: 'Nouvel utilisateur',
                    subtitle: 'Profil, flotte et autorisations',
                    icon: Icons.person_add_alt_1_rounded,
                    formKey: formKey,
                    cancelLabel: 'Annuler',
                    confirmLabel: 'Enregistrer',
                    child: Column(
                      children: List.generate(
                        10,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            decoration: corporateInputDecoration(
                              label: 'Champ ${index + 1}',
                              icon: Icons.edit_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvel utilisateur'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
