import 'package:flutter_test/flutter_test.dart';
import 'package:klondike_solitaire/models/card.dart';
import 'package:klondike_solitaire/models/game_state.dart';

void main() {
  group('deal', () {
    test('tableau has 28 cards dealt 1..7 with only the last face up', () {
      final gs = GameState();
      var total = 0;
      for (var i = 0; i < 7; i++) {
        expect(gs.tableau[i].length, i + 1);
        total += gs.tableau[i].length;
        for (var j = 0; j < gs.tableau[i].length; j++) {
          expect(gs.tableau[i][j].faceUp, j == gs.tableau[i].length - 1);
        }
      }
      expect(total, 28);
      expect(gs.stock.length, 24);
      expect(gs.stock.every((c) => !c.faceUp), isTrue);
    });
  });

  group('stock/waste', () {
    test('draw count moves cards from stock to waste face up', () {
      final gs = GameState()..setDrawCount(3);
      gs.tapStock();
      expect(gs.waste.length, 3);
      expect(gs.waste.every((c) => c.faceUp), isTrue);
      expect(gs.stock.length, 21);
    });

    test('recycling waste back into stock preserves draw order', () {
      final gs = GameState()..setDrawCount(1);
      while (gs.stock.isNotEmpty) {
        gs.tapStock();
      }
      expect(gs.waste.length, 24);
      final lastDrawn = gs.waste.last;
      gs.tapStock(); // recycle
      expect(gs.stock.length, 24);
      expect(gs.waste, isEmpty);
      // Recycling flips the waste pile back over, so re-drawing reproduces
      // the exact same original draw sequence: the most recently drawn card
      // ends up back on top of the (soon to be drawn again) stock... i.e.
      // at the bottom of the internal list, since draws happen via
      // removeLast().
      expect(gs.stock.first, lastDrawn);
      expect(gs.stock.every((c) => !c.faceUp), isTrue);
    });
  });

  group('move validation', () {
    test('only a King can be placed on an empty tableau pile', () {
      final gs = GameState();
      final queen = PlayingCard(suit: Suit.hearts, rank: 12, faceUp: true);
      final king = PlayingCard(suit: Suit.spades, rank: 13, faceUp: true);
      final sel = CardSelection(PileId.waste, 0, [queen]);
      final kingSel = CardSelection(PileId.waste, 0, [king]);
      final emptyTableau = gs.tableau.indexWhere((p) => p.isEmpty);
      // Force a pile empty for the test regardless of deal shape.
      final dest = PileId.tableau(emptyTableau >= 0 ? emptyTableau : 0);
      gs.tableau[dest.index].clear();

      expect(gs.canMove(sel, dest), isFalse);
      expect(gs.canMove(kingSel, dest), isTrue);
    });

    test('tableau builds must alternate color and descend by one rank', () {
      final gs = GameState();
      gs.tableau[0]
        ..clear()
        ..add(PlayingCard(suit: Suit.spades, rank: 8, faceUp: true));

      final redSeven = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.hearts, rank: 7, faceUp: true)]);
      final blackSeven = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.clubs, rank: 7, faceUp: true)]);
      final redSix = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.diamonds, rank: 6, faceUp: true)]);

      expect(gs.canMove(redSeven, PileId.tableau(0)), isTrue);
      expect(gs.canMove(blackSeven, PileId.tableau(0)), isFalse);
      expect(gs.canMove(redSix, PileId.tableau(0)), isFalse);
    });

    test('foundation requires an ace first, then ascending same suit', () {
      final gs = GameState();
      final aceSpades = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.spades, rank: 1, faceUp: true)]);
      final twoHearts = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.hearts, rank: 2, faceUp: true)]);
      final twoSpades = CardSelection(PileId.waste, 0, [PlayingCard(suit: Suit.spades, rank: 2, faceUp: true)]);

      expect(gs.canMove(twoSpades, PileId.foundation(0)), isFalse);
      expect(gs.canMove(aceSpades, PileId.foundation(0)), isTrue);

      gs.foundations[0].add(PlayingCard(suit: Suit.spades, rank: 1, faceUp: true));
      expect(gs.canMove(twoHearts, PileId.foundation(0)), isFalse);
      expect(gs.canMove(twoSpades, PileId.foundation(0)), isTrue);
    });

    test('a multi-card run can only move as a group if it is a valid alternating sequence', () {
      final gs = GameState();
      gs.tableau[0]
        ..clear()
        ..addAll([
          PlayingCard(suit: Suit.clubs, rank: 9, faceUp: true),
          PlayingCard(suit: Suit.hearts, rank: 8, faceUp: true),
          PlayingCard(suit: Suit.spades, rank: 7, faceUp: true),
        ]);
      final validRun = gs.movableStack(PileId.tableau(0), 0);
      expect(validRun, isNotNull);
      expect(validRun!.cards.length, 3);

      gs.tableau[1]
        ..clear()
        ..addAll([
          PlayingCard(suit: Suit.clubs, rank: 9, faceUp: true),
          PlayingCard(suit: Suit.hearts, rank: 5, faceUp: true), // not in sequence
        ]);
      final invalidRun = gs.movableStack(PileId.tableau(1), 0);
      expect(invalidRun, isNull);
      // The top card alone is still movable.
      final topOnly = gs.movableStack(PileId.tableau(1), 1);
      expect(topOnly, isNotNull);
      expect(topOnly!.cards.length, 1);
    });
  });

  group('win detection', () {
    test('game is won once all four foundations hold 13 cards', () {
      final gs = GameState();
      for (var s = 0; s < 4; s++) {
        for (var r = 1; r <= 13; r++) {
          gs.foundations[s].add(PlayingCard(suit: Suit.values[s], rank: r, faceUp: true));
        }
      }
      gs.tableau[0].clear();
      // Trigger the win check the same way a real move would.
      final sel = CardSelection(PileId.tableau(0), 0, [PlayingCard(suit: Suit.spades, rank: 13, faceUp: true)]);
      gs.tableau[1]
        ..clear()
        ..add(sel.cards.first);
      gs.foundations[0].removeLast();
      final moved = gs.tryMove(CardSelection(PileId.tableau(1), 0, [sel.cards.first]), PileId.foundation(0));
      expect(moved, isTrue);
      expect(gs.won, isTrue);
    });
  });

  group('undo', () {
    test('undo restores stock/waste after a draw', () {
      final gs = GameState()..setDrawCount(1);
      final stockBefore = gs.stock.length;
      gs.tapStock();
      expect(gs.stock.length, stockBefore - 1);
      gs.undo();
      expect(gs.stock.length, stockBefore);
      expect(gs.waste, isEmpty);
    });
  });
}
