import 'package:flutter/foundation.dart';

import 'card.dart';

enum PileType { stock, waste, foundation, tableau }

/// Identifies a specific pile: stock/waste are singletons, foundation and
/// tableau each have 4/7 indexed instances.
@immutable
class PileId {
  final PileType type;
  final int index;
  const PileId(this.type, [this.index = 0]);

  static const stock = PileId(PileType.stock);
  static const waste = PileId(PileType.waste);
  static PileId foundation(int i) => PileId(PileType.foundation, i);
  static PileId tableau(int i) => PileId(PileType.tableau, i);

  @override
  bool operator ==(Object other) =>
      other is PileId && other.type == type && other.index == index;
  @override
  int get hashCode => Object.hash(type, index);
  @override
  String toString() => '${type.name}[$index]';
}

/// A group of one or more cards (in original pile order) picked up from a
/// specific pile starting at [cardIndex], currently selected or being
/// dragged.
class CardSelection {
  final PileId source;
  final int cardIndex;
  final List<PlayingCard> cards;
  CardSelection(this.source, this.cardIndex, this.cards);
}

class _Snapshot {
  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;
  final int moves;
  _Snapshot(this.stock, this.waste, this.foundations, this.tableau, this.moves);
}

class GameState extends ChangeNotifier {
  List<PlayingCard> stock = [];
  List<PlayingCard> waste = [];
  List<List<PlayingCard>> foundations = List.generate(4, (_) => <PlayingCard>[]);
  List<List<PlayingCard>> tableau = List.generate(7, (_) => <PlayingCard>[]);

  /// How many cards are drawn from the stock at a time (1 or 3).
  int drawCount = 1;

  int moves = 0;
  bool won = false;

  CardSelection? selection;

  final List<_Snapshot> _undoStack = [];

  GameState() {
    newGame();
  }

  void newGame() {
    final deck = createShuffledDeck();
    stock = [];
    waste = [];
    foundations = List.generate(4, (_) => <PlayingCard>[]);
    tableau = List.generate(7, (_) => <PlayingCard>[]);
    moves = 0;
    won = false;
    selection = null;
    _undoStack.clear();

    var deckIndex = 0;
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row <= col; row++) {
        final card = deck[deckIndex++];
        card.faceUp = row == col;
        tableau[col].add(card);
      }
    }
    stock = deck.sublist(deckIndex).map((c) => c..faceUp = false).toList();
    notifyListeners();
  }

  void setDrawCount(int n) {
    if (n != 1 && n != 3) return;
    drawCount = n;
    notifyListeners();
  }

  List<PlayingCard> pileFor(PileId id) {
    switch (id.type) {
      case PileType.stock:
        return stock;
      case PileType.waste:
        return waste;
      case PileType.foundation:
        return foundations[id.index];
      case PileType.tableau:
        return tableau[id.index];
    }
  }

  void _pushUndo() {
    _undoStack.add(_Snapshot(
      stock.map((c) => c.copy()).toList(),
      waste.map((c) => c.copy()).toList(),
      foundations.map((p) => p.map((c) => c.copy()).toList()).toList(),
      tableau.map((p) => p.map((c) => c.copy()).toList()).toList(),
      moves,
    ));
    if (_undoStack.length > 200) _undoStack.removeAt(0);
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    final s = _undoStack.removeLast();
    stock = s.stock;
    waste = s.waste;
    foundations = s.foundations;
    tableau = s.tableau;
    moves = s.moves;
    won = false;
    selection = null;
    notifyListeners();
  }

  // ---- Stock / waste ----

  void tapStock() {
    _pushUndo();
    if (stock.isEmpty) {
      if (waste.isEmpty) {
        _undoStack.removeLast();
        return;
      }
      // Recycle waste back into stock, face down, preserving draw order.
      stock = waste.reversed.map((c) => c..faceUp = false).toList();
      waste = [];
    } else {
      final n = drawCount.clamp(0, stock.length);
      for (var i = 0; i < n; i++) {
        final card = stock.removeLast();
        card.faceUp = true;
        waste.add(card);
      }
    }
    selection = null;
    moves++;
    notifyListeners();
  }

  // ---- Selection / movement rules ----

  bool _isRun(List<PlayingCard> cards) {
    for (var i = 0; i < cards.length - 1; i++) {
      final a = cards[i];
      final b = cards[i + 1];
      if (!a.faceUp || !b.faceUp) return false;
      if (a.isRed == b.isRed) return false;
      if (a.rank != b.rank + 1) return false;
    }
    return true;
  }

  /// Returns the movable stack starting at [cardIndex] in [pileId], or null
  /// if that card cannot be picked up (face down, not part of a valid run,
  /// or pile doesn't support multi-card picks e.g. foundation).
  CardSelection? movableStack(PileId pileId, int cardIndex) {
    final pile = pileFor(pileId);
    if (cardIndex < 0 || cardIndex >= pile.length) return null;
    final card = pile[cardIndex];
    if (!card.faceUp) return null;

    switch (pileId.type) {
      case PileType.stock:
        return null;
      case PileType.waste:
      case PileType.foundation:
        if (cardIndex != pile.length - 1) return null;
        return CardSelection(pileId, cardIndex, [card]);
      case PileType.tableau:
        final sub = pile.sublist(cardIndex);
        if (!_isRun(sub)) return null;
        return CardSelection(pileId, cardIndex, sub);
    }
  }

  bool isTopCard(PileId pileId, int cardIndex) {
    final pile = pileFor(pileId);
    return cardIndex == pile.length - 1;
  }

  bool _canPlaceOnFoundation(PlayingCard card, int foundationIndex) {
    final pile = foundations[foundationIndex];
    if (pile.isEmpty) return card.rank == 1;
    final top = pile.last;
    return top.suit == card.suit && top.rank == card.rank - 1;
  }

  bool _canPlaceOnTableau(List<PlayingCard> moving, int tableauIndex) {
    final pile = tableau[tableauIndex];
    final first = moving.first;
    if (pile.isEmpty) return first.rank == 13;
    final top = pile.last;
    if (!top.faceUp) return false;
    return top.isRed != first.isRed && top.rank == first.rank + 1;
  }

  /// Pure validity check - does not mutate state. Safe to call repeatedly
  /// from drag-target hover callbacks.
  bool canMove(CardSelection sel, PileId dest) {
    if (dest == sel.source) return false;
    switch (dest.type) {
      case PileType.stock:
        return false;
      case PileType.waste:
        return false;
      case PileType.foundation:
        if (sel.cards.length != 1) return false;
        return _canPlaceOnFoundation(sel.cards.single, dest.index);
      case PileType.tableau:
        return _canPlaceOnTableau(sel.cards, dest.index);
    }
  }

  /// Attempts to find *any* foundation pile that will accept this single
  /// card, used for the quick tap-to-send-to-foundation gesture.
  PileId? _autoFoundationTarget(PlayingCard card) {
    for (var i = 0; i < 4; i++) {
      if (_canPlaceOnFoundation(card, i)) return PileId.foundation(i);
    }
    return null;
  }

  /// Executes a validated move. Caller must have already confirmed
  /// [canMove] (or be [tryMove], which checks first).
  void _executeMove(CardSelection sel, PileId dest) {
    _pushUndo();
    final source = pileFor(sel.source);
    source.removeRange(sel.cardIndex, source.length);
    if (sel.source.type == PileType.tableau && source.isNotEmpty && !source.last.faceUp) {
      source.last.faceUp = true;
    }
    pileFor(dest).addAll(sel.cards);
    moves++;
    selection = null;
    _checkWin();
    notifyListeners();
  }

  bool tryMove(CardSelection sel, PileId dest) {
    if (!canMove(sel, dest)) return false;
    _executeMove(sel, dest);
    return true;
  }

  void _checkWin() {
    won = foundations.every((p) => p.length == 13);
  }

  /// Handles a tap on a specific card. Implements: tap empty stock area is
  /// handled separately via [tapStock]; tapping a movable top card with no
  /// active selection first tries auto-move to a foundation, otherwise
  /// selects it; tapping while something is selected attempts to move the
  /// selection to the tapped pile.
  void tapCard(PileId pileId, int cardIndex) {
    if (selection == null) {
      final card = pileFor(pileId)[cardIndex];
      if (isTopCard(pileId, cardIndex) &&
          pileId.type != PileType.foundation &&
          card.faceUp) {
        final target = _autoFoundationTarget(card);
        if (target != null) {
          final sel = CardSelection(pileId, cardIndex, [card]);
          _executeMove(sel, target);
          return;
        }
      }
      final stack = movableStack(pileId, cardIndex);
      if (stack != null) {
        selection = stack;
        notifyListeners();
      }
      return;
    }

    final current = selection!;
    if (current.source == pileId && current.cardIndex == cardIndex) {
      selection = null;
      notifyListeners();
      return;
    }

    final moved = tryMove(current, pileId);
    if (!moved) {
      final stack = movableStack(pileId, cardIndex);
      selection = stack;
    }
    notifyListeners();
  }

  /// Handles a tap on empty pile space (no cards to index into).
  void tapEmptyPile(PileId pileId) {
    if (selection == null) return;
    final current = selection!;
    final moved = tryMove(current, pileId);
    if (moved) return;
    selection = null;
    notifyListeners();
  }

  void clearSelection() {
    if (selection != null) {
      selection = null;
      notifyListeners();
    }
  }
}
