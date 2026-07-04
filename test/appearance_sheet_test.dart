import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klondike_solitaire/models/app_theme.dart';
import 'package:klondike_solitaire/widgets/app_theme_scope.dart';
import 'package:klondike_solitaire/widgets/appearance_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('picking a card back and table updates AppTheme', (tester) async {
    final theme = AppTheme();

    await tester.pumpWidget(
      AppThemeScope(
        theme: theme,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAppearanceSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Card Back'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);

    await tester.tap(find.text('Crimson'));
    await tester.pumpAndSettle();
    expect(theme.cardBackStyle, CardBackStyle.crimson);

    await tester.tap(find.text('Walnut'));
    await tester.pumpAndSettle();
    expect(theme.tableTheme, TableTheme.walnut);
  });
}
