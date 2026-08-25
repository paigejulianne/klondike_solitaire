import 'package:flutter_test/flutter_test.dart';
import 'package:klondike_solitaire/models/card.dart';
import 'package:klondike_solitaire/models/game_state.dart';

PlayingCard c(Suit suit, int rank, {bool up = true}) =>
    PlayingCard(suit: suit, rank: rank, faceUp: up);

/// A dealt game with every pile emptied, so each test can build the exact
/// position it cares about.
GameState blankGame() {
  final gs = GameState();
  gs.stock.clear();
  gs.waste.clear();
  for (final f in gs.foundations) {
    f.clear();
  }
  for (final t in gs.tableau) {
    t.clear();
  }
  return gs;
}

void main() {
  group('safe autoplay', () {
    test('aces and twos are always safe', () {
      final gs = blankGame();
      expect(gs.isSafeToAutoplay(c(Suit.spades, 1)), isTrue);
      expect(gs.isSafeToAutoplay(c(Suit.hearts, 2)), isTrue);
    });

    test('a card is unsafe while a lower opposite-colour card is still out', () {
      final gs = blankGame();
      gs.foundations[0].addAll([for (var r = 1; r <= 4; r++) c(Suit.diamonds, r)]);
      gs.foundations[1].add(c(Suit.spades, 1));
      gs.foundations[2].add(c(Suit.clubs, 1));
      // A black 4 could still need the 5 of diamonds, so holding it back.
      expect(gs.isSafeToAutoplay(c(Suit.diamonds, 5)), isFalse);
    });

    test('a card becomes safe once both opposite colours have caught up', () {
      final gs = blankGame();
      gs.foundations[0].addAll([for (var r = 1; r <= 4; r++) c(Suit.diamonds, r)]);
      gs.foundations[1].addAll([for (var r = 1; r <= 4; r++) c(Suit.spades, r)]);
      gs.foundations[2].addAll([for (var r = 1; r <= 4; r++) c(Suit.clubs, r)]);
      gs.foundations[3].addAll([for (var r = 1; r <= 3; r++) c(Suit.hearts, r)]);
      expect(gs.isSafeToAutoplay(c(Suit.diamonds, 5)), isTrue);
    });
  });

  group('solve', () {
    test('sweeps every safe card up to the foundations', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));
      gs.tableau[1].add(c(Suit.hearts, 1));
      gs.tableau[2].add(c(Suit.hearts, 2));
      gs.waste.add(c(Suit.diamonds, 1));

      expect(gs.canSolve, isTrue);
      var steps = 0;
      while (gs.solveStep()) {
        steps++;
        expect(steps, lessThan(60), reason: 'solve should terminate');
      }

      expect(steps, 4);
      expect(gs.tableau.every((p) => p.isEmpty), isTrue);
      expect(gs.waste, isEmpty);
      expect(gs.foundationRank(Suit.hearts), 2);
      expect(gs.foundationRank(Suit.spades), 1);
      expect(gs.foundationRank(Suit.diamonds), 1);
    });

    test('leaves an unsafe card in the tableau while cards are still hidden', () {
      final gs = blankGame();
      gs.foundations[0].addAll([for (var r = 1; r <= 4; r++) c(Suit.diamonds, r)]);
      gs.foundations[1].add(c(Suit.spades, 1));
      gs.foundations[2].add(c(Suit.clubs, 1));
      gs.tableau[0].addAll([c(Suit.clubs, 9, up: false), c(Suit.diamonds, 5)]);

      expect(gs.canFinish, isFalse);
      expect(gs.canSolve, isFalse);
      expect(gs.solveStep(), isFalse);
      expect(gs.tableau[0].last.rank, 5);
    });

    test('ignores the safety rule once nothing is face down', () {
      final gs = blankGame();
      gs.foundations[0].addAll([for (var r = 1; r <= 4; r++) c(Suit.diamonds, r)]);
      gs.foundations[1].add(c(Suit.spades, 1));
      gs.foundations[2].add(c(Suit.clubs, 1));
      gs.tableau[0].addAll([c(Suit.clubs, 9), c(Suit.diamonds, 5)]);

      expect(gs.canFinish, isTrue);
      expect(gs.solveStep(), isTrue);
      expect(gs.foundationRank(Suit.diamonds), 5);
    });

    test('draws from the stock during the finish sweep', () {
      final gs = blankGame();
      gs.foundations[0].add(c(Suit.spades, 1));
      // Ace of hearts is buried one draw deep in the stock.
      gs.stock.addAll([c(Suit.hearts, 1, up: false), c(Suit.clubs, 9, up: false)]);

      expect(gs.canFinish, isTrue);
      var steps = 0;
      while (gs.solveStep() && steps < 60) {
        steps++;
      }
      expect(gs.foundationRank(Suit.hearts), 1);
    });

    test('a whole solve run collapses into one undo step', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));
      gs.tableau[1].add(c(Suit.hearts, 1));

      gs.beginBatch();
      while (gs.solveStep()) {}
      gs.endBatch();

      expect(gs.foundations.where((p) => p.isNotEmpty).length, 2);
      expect(gs.canUndo, isTrue);
      gs.undo();
      expect(gs.foundations.every((p) => p.isEmpty), isTrue);
      expect(gs.tableau[0].single.rank, 1);
      expect(gs.canUndo, isFalse);
    });

    test('a batch that does nothing leaves no undo step behind', () {
      final gs = blankGame();
      gs.beginBatch();
      expect(gs.solveStep(), isFalse);
      gs.endBatch();
      expect(gs.canUndo, isFalse);
    });
  });

  group('redo', () {
    test('redo replays an undone move', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));

      expect(gs.tryMove(gs.movableStack(PileId.tableau(0), 0)!, PileId.foundation(0)),
          isTrue);
      expect(gs.canRedo, isFalse);

      gs.undo();
      expect(gs.tableau[0].single.rank, 1);
      expect(gs.canRedo, isTrue);

      gs.redo();
      expect(gs.tableau[0], isEmpty);
      expect(gs.foundations[0].single.rank, 1);
    });

    test('making a fresh move clears the redo stack', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));
      gs.tableau[1].add(c(Suit.hearts, 1));

      gs.tryMove(gs.movableStack(PileId.tableau(0), 0)!, PileId.foundation(0));
      gs.undo();
      expect(gs.canRedo, isTrue);

      gs.tryMove(gs.movableStack(PileId.tableau(1), 0)!, PileId.foundation(0));
      expect(gs.canRedo, isFalse);
    });
  });

  group('hints', () {
    test('prefers a move that uncovers a face-down card', () {
      final gs = blankGame();
      gs.tableau[0].addAll([c(Suit.clubs, 4, up: false), c(Suit.hearts, 6)]);
      gs.tableau[1].add(c(Suit.spades, 7));

      final hint = gs.findHint();
      expect(hint, isNotNull);
      expect(hint!.move!.selection.source, PileId.tableau(0));
      expect(hint.move!.dest, PileId.tableau(1));
    });

    test('suggests drawing when the stock holds something playable', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 7));
      gs.stock.add(c(Suit.hearts, 6, up: false));

      final hint = gs.findHint();
      expect(hint, isNotNull);
      expect(hint!.isDraw, isTrue);
    });

    test('reports no hint on a dead board', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 2));
      gs.tableau[1].add(c(Suit.clubs, 4));

      expect(gs.findHint(), isNull);
      expect(gs.isStuck, isTrue);
    });

    test('a board with a playable ace is not stuck', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));
      expect(gs.isStuck, isFalse);
    });
  });

  group('scoring', () {
    test('banking a card scores, and uncovering one scores again', () {
      final gs = blankGame();
      gs.tableau[0].addAll([c(Suit.clubs, 9, up: false), c(Suit.spades, 1)]);

      gs.tryMove(gs.movableStack(PileId.tableau(0), 1)!, PileId.foundation(0));
      // +10 for the foundation, +5 for turning the club over.
      expect(gs.score, 15);
      expect(gs.tableau[0].single.faceUp, isTrue);
    });

    test('recycling the waste costs points but never goes negative', () {
      final gs = blankGame()..setDrawCount(1);
      gs.waste.add(c(Suit.clubs, 9));
      gs.tapStock();
      expect(gs.score, 0);
    });
  });

  group('double tap', () {
    test('two quick taps send a card to a foundation', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 1));

      gs.tapCard(PileId.tableau(0), 0);
      expect(gs.selection, isNotNull, reason: 'first tap only selects');
      expect(gs.tableau[0], isNotEmpty);

      gs.tapCard(PileId.tableau(0), 0);
      expect(gs.tableau[0], isEmpty);
      expect(gs.foundations[0].single.rank, 1);
    });

    test('two quick taps on a card with nowhere to go just deselect it', () {
      final gs = blankGame();
      gs.tableau[0].add(c(Suit.spades, 9));

      gs.tapCard(PileId.tableau(0), 0);
      expect(gs.selection, isNotNull);
      gs.tapCard(PileId.tableau(0), 0);
      expect(gs.selection, isNull);
      expect(gs.tableau[0], isNotEmpty);
    });
  });

  group('auto-save', () {
    test('a saved game round-trips exactly', () {
      final original = GameState()..setDrawCount(3);
      original.tapStock();
      original.tapStock();
      final encoded = original.encode();

      final restored = GameState(deal: false);
      expect(restored.restore(encoded), isTrue);

      expect(restored.drawCount, 3);
      expect(restored.moves, original.moves);
      expect(restored.score, original.score);
      expect(restored.stock.map((c) => c.id).toList(),
          original.stock.map((c) => c.id).toList());
      expect(restored.waste.map((c) => c.id).toList(),
          original.waste.map((c) => c.id).toList());
      for (var i = 0; i < 7; i++) {
        expect(restored.tableau[i].map((c) => c.id).toList(),
            original.tableau[i].map((c) => c.id).toList());
        expect(restored.tableau[i].map((c) => c.faceUp).toList(),
            original.tableau[i].map((c) => c.faceUp).toList());
      }
    });

    test('a corrupt or incomplete save is rejected', () {
      final gs = GameState();
      final before = gs.tableau[0].map((c) => c.id).toList();

      expect(gs.restore(null), isFalse);
      expect(gs.restore(''), isFalse);
      expect(gs.restore('not json at all'), isFalse);
      expect(gs.restore('{}'), isFalse);

      // Structurally valid but missing a card.
      final short = GameState();
      short.stock.removeLast();
      expect(gs.restore(short.encode()), isFalse);

      expect(gs.tableau[0].map((c) => c.id).toList(), before);
    });

    test('a restored game does not replay the deal animation', () {
      final source = GameState();
      final restored = GameState(deal: false);
      expect(restored.restore(source.encode()), isTrue);
      expect(restored.animateDeal, isFalse);
    });
  });
}
