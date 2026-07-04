import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klondike_solitaire/widgets/win_celebration.dart';

void main() {
  testWidgets('WinCelebration shows the win panel and cascades cards', (tester) async {
    var newGameTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WinCelebration(
            moves: 87,
            onNewGame: () => newGameTapped = true,
          ),
        ),
      ),
    );

    // Let the ticker run for a bit so cards spawn and the panel fades in.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('You Win!'), findsOneWidget);
    expect(find.text('Solved in 87 moves'), findsOneWidget);

    await tester.tap(find.text('New Game'));
    expect(newGameTapped, isTrue);
  });
}
