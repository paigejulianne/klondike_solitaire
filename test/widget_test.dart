import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klondike_solitaire/main.dart';
import 'package:klondike_solitaire/models/app_theme.dart';
import 'package:klondike_solitaire/widgets/card_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App launches and shows the game board', (WidgetTester tester) async {
    await tester.pumpWidget(KlondikeApp(appTheme: AppTheme()));
    await tester.pumpAndSettle();

    expect(find.text('Klondike Solitaire'), findsOneWidget);
    // 52 cards plus the 13 empty-pile placeholders they sit on.
    expect(find.byType(CardView), findsNWidgets(65));
  });

  testWidgets('Solve and hint controls are present', (WidgetTester tester) async {
    await tester.pumpWidget(KlondikeApp(appTheme: AppTheme()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Solve (S)'), findsOneWidget);
    expect(find.byTooltip('Hint (H)'), findsOneWidget);
    expect(find.byTooltip('Undo (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Redo (Ctrl+Y)'), findsOneWidget);
  });

  testWidgets('Narrow layout drops the title and keeps the board playable',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(KlondikeApp(appTheme: AppTheme()));
    await tester.pumpAndSettle();

    // The title gives way to the stats row, and New Game moves into the menu.
    expect(find.text('Klondike Solitaire'), findsNothing);
    expect(find.byTooltip('New Game (N)'), findsNothing);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byType(CardView), findsNWidgets(65));
  });
}
