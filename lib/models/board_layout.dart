import 'dart:math';

import 'package:flutter/widgets.dart';

import 'card.dart';
import 'game_state.dart';

/// Where everything sits on the table.
///
/// The board is drawn as one absolutely-positioned layer, so every card's
/// home is a pure function of the game state. Moving a card just changes the
/// offset this returns, and the view animates between the two - which is why
/// there is no separate "flying card" machinery anywhere in the widget tree.
@immutable
class BoardLayout {
  final double cardWidth;
  final double cardHeight;
  final double spacing;

  /// Vertical step between stacked tableau cards. Squeezed on short screens
  /// so a long column still fits without scrolling.
  final double faceDownStep;
  final double faceUpStep;

  /// Horizontal step between the fanned waste cards.
  final double wasteStep;

  final List<double> columnX;
  final double topRowY;
  final double tableauTop;
  final Size size;

  const BoardLayout._({
    required this.cardWidth,
    required this.cardHeight,
    required this.spacing,
    required this.faceDownStep,
    required this.faceUpStep,
    required this.wasteStep,
    required this.columnX,
    required this.topRowY,
    required this.tableauTop,
    required this.size,
  });

  /// How many waste cards are fanned out; the rest sit hidden underneath.
  static const wasteFanCount = 3;

  static const _minCardWidth = 44.0;
  static const _maxCardWidth = 220.0;

  /// Aspect ratio of a card, height over width.
  static const _aspect = 1.42;

  /// How deep a tableau column we size for before the stacking has to be
  /// squeezed: the top row, a column's base card, and eight cards fanned
  /// below it.
  static const _designColumnDepth = 8;

  factory BoardLayout.forViewport({
    required Size viewport,
    required GameState game,
  }) {
    const spacing = 8.0;
    const columns = 7;

    // Cards grow to fill the table, limited by whichever runs out first: the
    // width of seven columns, or the height of the top row plus a
    // comfortably deep tableau column.
    final byWidth = (viewport.width - spacing * (columns + 1)) / columns;
    final heightUnits = 2 + _designColumnDepth * 0.30;
    final byHeight =
        (viewport.height - spacing * 2.5) / (_aspect * heightUnits);
    final cardWidth = min(byWidth, byHeight).clamp(_minCardWidth, _maxCardWidth);
    final cardHeight = cardWidth * _aspect;

    // Seven evenly spaced columns. On a wide screen the gap is capped and
    // the whole board centred, rather than smearing the columns across the
    // full width of the window.
    final free = viewport.width - cardWidth * columns;
    final gap = (free / (columns + 1)).clamp(spacing * 0.75, cardWidth * 0.22);
    final boardWidth = cardWidth * columns + gap * (columns - 1);
    final originX = max(0.0, (viewport.width - boardWidth) / 2);
    final columnX = [
      for (var i = 0; i < columns; i++) originX + i * (cardWidth + gap),
    ];

    final topRowY = 0.0;
    final tableauTop = cardHeight + spacing * 2.5;

    var faceDownStep = cardHeight * 0.20;
    var faceUpStep = cardHeight * 0.30;

    // Squeeze the stacking so the tallest column still fits the viewport.
    final tallest = _tallestColumnExtent(game, cardHeight, faceDownStep, faceUpStep);
    final available = viewport.height - tableauTop - spacing;
    if (tallest > available && tallest > cardHeight) {
      final slack = (available - cardHeight) / (tallest - cardHeight);
      final factor = slack.clamp(0.35, 1.0);
      faceDownStep *= factor;
      faceUpStep *= factor;
    }

    var boardHeight = tableauTop + cardHeight;
    for (var c = 0; c < columns; c++) {
      final extent = tableauTop +
          _columnExtent(game.tableau[c], cardHeight, faceDownStep, faceUpStep);
      boardHeight = max(boardHeight, extent);
    }

    return BoardLayout._(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      spacing: spacing,
      faceDownStep: faceDownStep,
      faceUpStep: faceUpStep,
      wasteStep: cardWidth * 0.30,
      columnX: columnX,
      topRowY: topRowY,
      tableauTop: tableauTop,
      size: Size(viewport.width, max(boardHeight, viewport.height)),
    );
  }

  static double _columnExtent(
    List<PlayingCard> cards,
    double cardHeight,
    double faceDownStep,
    double faceUpStep,
  ) {
    if (cards.isEmpty) return cardHeight;
    var top = 0.0;
    for (var i = 0; i < cards.length - 1; i++) {
      top += cards[i].faceUp ? faceUpStep : faceDownStep;
    }
    return top + cardHeight;
  }

  static double _tallestColumnExtent(
    GameState game,
    double cardHeight,
    double faceDownStep,
    double faceUpStep,
  ) {
    var tallest = cardHeight;
    for (final column in game.tableau) {
      tallest = max(
        tallest,
        _columnExtent(column, cardHeight, faceDownStep, faceUpStep),
      );
    }
    return tallest;
  }

  Size get cardSize => Size(cardWidth, cardHeight);

  // The top row reuses tableau column slots so everything lines up:
  // stock over column 0, waste over column 1, foundations over columns 3-6.
  double get stockX => columnX[0];
  double get wasteX => columnX[1];
  double foundationX(int i) => columnX[3 + i];

  /// Top-left of an empty pile's placeholder slot.
  Offset slotOrigin(PileId pile) {
    switch (pile.type) {
      case PileType.stock:
        return Offset(stockX, topRowY);
      case PileType.waste:
        return Offset(wasteX, topRowY);
      case PileType.foundation:
        return Offset(foundationX(pile.index), topRowY);
      case PileType.tableau:
        return Offset(columnX[pile.index], tableauTop);
    }
  }

  /// Where the card at [index] of [pile] should be drawn.
  Offset positionOf(PileId pile, int index, GameState game) {
    final origin = slotOrigin(pile);
    switch (pile.type) {
      case PileType.stock:
      case PileType.foundation:
        return origin;
      case PileType.waste:
        final cards = game.waste;
        final firstFanned = max(0, cards.length - wasteFanCount);
        final slot = max(0, index - firstFanned);
        return Offset(origin.dx + wasteStep * slot, origin.dy);
      case PileType.tableau:
        final cards = game.tableau[pile.index];
        var top = origin.dy;
        for (var i = 0; i < index && i < cards.length; i++) {
          top += cards[i].faceUp ? faceUpStep : faceDownStep;
        }
        return Offset(origin.dx, top);
    }
  }

  /// Where the *next* card added to [pile] would land - used to park the
  /// highlight ring on an empty pile and to seed the deal animation.
  Offset landingPosition(PileId pile, GameState game) =>
      positionOf(pile, game.pileFor(pile).length, game);

  /// The card-sized rectangle a drop would land on, which is the top card of
  /// the pile rather than the pile's origin.
  Rect dropRect(PileId pile, GameState game) {
    final cards = game.pileFor(pile);
    final origin = cards.isEmpty
        ? slotOrigin(pile)
        : positionOf(pile, cards.length - 1, game);
    return origin & cardSize;
  }

  /// The full hit area of a pile, covering every card in the column so a
  /// drop anywhere along it registers.
  Rect hitRect(PileId pile, GameState game) {
    final origin = slotOrigin(pile);
    if (pile.type != PileType.tableau) {
      if (pile.type == PileType.waste) {
        final extra = wasteStep * (min(game.waste.length, wasteFanCount) - 1);
        return origin & Size(cardWidth + max(0.0, extra), cardHeight);
      }
      return origin & cardSize;
    }
    final extent =
        _columnExtent(game.tableau[pile.index], cardHeight, faceDownStep, faceUpStep);
    // Empty columns get a generous target so they are easy to hit.
    return origin & Size(cardWidth, max(extent, cardHeight));
  }
}
