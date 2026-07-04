import 'package:flutter_test/flutter_test.dart';

import 'package:klondike_solitaire/main.dart';
import 'package:klondike_solitaire/models/app_theme.dart';

void main() {
  testWidgets('App launches and shows the game board', (WidgetTester tester) async {
    await tester.pumpWidget(KlondikeApp(appTheme: AppTheme()));
    await tester.pumpAndSettle();

    expect(find.text('Klondike Solitaire'), findsOneWidget);
    expect(find.text('Moves: 0'), findsOneWidget);
  });
}
