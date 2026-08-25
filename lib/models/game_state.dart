import 'dart:convert';

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

/// A concrete move: take [selection] and put it on [dest].
@immutable
class Move {
  final CardSelection selection;
  final PileId dest;
  const Move(this.selection, this.dest);
}

/// A suggested next action. [move] is null when the suggestion is "draw from
/// the stock", which has no source card or destination of its own.
@immutable
class Hint {
  final Move? move;
  final String description;
  const Hint({this.move, required this.description});

  bool get isDraw => move == null;
}

class _Snapshot {
  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;
  final int moves;
  final int score;
  final int passes;
  _Snapshot(this.stock, this.waste, this.foundations, this.tableau, this.moves,
      this.score, this.passes);
}

class GameState extends ChangeNotifier {
  List<PlayingCard> stock = [];
  List<PlayingCard> waste = [];
  List<List<PlayingCard>> foundations = List.generate(4, (_) => <PlayingCard>[]);
  List<List<PlayingCard>> tableau = List.generate(7, (_) => <PlayingCard>[]);

  /// How many cards are drawn from the stock at a time (1 or 3).
  int drawCount = 1;

  int moves = 0;
  int score = 0;
  bool won = false;

  /// How many times the waste has been recycled back into the stock.
  int passes = 0;

  /// Bumped on every fresh deal (or restore) so the view can rebuild its card
  /// widgets from scratch instead of sliding the old ones across the board.
  int dealSerial = 0;

  /// Whether the view should play the opening deal animation for the current
  /// [dealSerial]. False for a restored game, which is already in progress.
  bool animateDeal = false;

  /// The cards touched by the most recent move, so the view can draw them on
  /// top of everything else while they are in flight.
  Set<String> lastMovedCardIds = const {};

  /// The card(s) picked up by tapping, waiting for a destination tap.
  CardSelection? selection;

  /// The card(s) currently held in a drag gesture. Set by the view so every
  /// pile can preview whether it would accept the drop.
  CardSelection? dragging;

  /// The most recent hint, shown until the player moves.
  Hint? activeHint;

  final List<_Snapshot> _undoStack = [];
  final List<_Snapshot> _redoStack = [];

  int _batchDepth = 0;
  int _batchStartMoves = 0;

  final Stopwatch _clock = Stopwatch();
  Duration _clockBase = Duration.zero;

  /// Invoked after any change worth writing to the auto-save slot.
  VoidCallback? onPersist;

  GameState({bool deal = true}) {
    if (deal) newGame();
  }

  /// Wall-clock time spent on the current game, paused once it is won.
  Duration get elapsed => _clockBase + _clock.elapsed;

  void newGame([int? seed]) {
    final deck = createShuffledDeck(seed);
    stock = [];
    waste = [];
    foundations = List.generate(4, (_) => <PlayingCard>[]);
    tableau = List.generate(7, (_) => <PlayingCard>[]);
    moves = 0;
    score = 0;
    passes = 0;
    won = false;
    selection = null;
    dragging = null;
    activeHint = null;
    dealSerial++;
    animateDeal = true;
    lastMovedCardIds = const {};
    _undoStack.clear();
    _redoStack.clear();
    _batchDepth = 0;
    _resetClock();

    var deckIndex = 0;
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row <= col; row++) {
        final card = deck[deckIndex++];
        card.faceUp = row == col;
        tableau[col].add(card);
      }
    }
    stock = deck.sublist(deckIndex).map((c) => c..faceUp = false).toList();
    _changed();
  }

  void setDrawCount(int n) {
    if (n != 1 && n != 3) return;
    if (n == drawCount) return;
    drawCount = n;
    _changed();
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

  void _changed() {
    notifyListeners();
    onPersist?.call();
  }

  void _resetClock() {
    _clock
      ..stop()
      ..reset();
    _clockBase = Duration.zero;
  }

  void _startClock() {
    if (!_clock.isRunning && !won) _clock.start();
  }

  // ---- Undo / redo ----

  _Snapshot _capture() => _Snapshot(
        stock.map((c) => c.copy()).toList(),
        waste.map((c) => c.copy()).toList(),
        foundations.map((p) => p.map((c) => c.copy()).toList()).toList(),
        tableau.map((p) => p.map((c) => c.copy()).toList()).toList(),
        moves,
        score,
        passes,
      );

  void _restore(_Snapshot s) {
    stock = s.stock;
    waste = s.waste;
    foundations = s.foundations;
    tableau = s.tableau;
    moves = s.moves;
    score = s.score;
    passes = s.passes;
  }

  void _remember() {
    _undoStack.add(_capture());
    if (_undoStack.length > 300) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _pushUndo() {
    // Inside a batch the opening snapshot already covers everything that
    // follows, so a whole solve run collapses into one undo step.
    if (_batchDepth > 0) return;
    _remember();
  }

  /// Groups every move made until the matching [endBatch] into one undo step.
  void beginBatch() {
    if (_batchDepth++ == 0) {
      _batchStartMoves = moves;
      _remember();
    }
  }

  void endBatch() {
    if (_batchDepth == 0) return;
    if (--_batchDepth == 0 &&
        moves == _batchStartMoves &&
        _undoStack.isNotEmpty) {
      // The batch did nothing; don't leave a no-op undo step behind.
      _undoStack.removeLast();
    }
  }

  bool get inBatch => _batchDepth > 0;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    final redoPoint = _capture();
    _restore(_undoStack.removeLast());
    _redoStack.add(redoPoint);
    lastMovedCardIds = const {};
    won = false;
    selection = null;
    activeHint = null;
    _startClock();
    _changed();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_capture());
    _restore(_redoStack.removeLast());
    lastMovedCardIds = const {};
    selection = null;
    activeHint = null;
    _checkWin();
    _changed();
  }

  // ---- Stock / waste ----

  void tapStock() {
    if (stock.isEmpty && waste.isEmpty) return;
    _pushUndo();
    _startClock();
    if (stock.isEmpty) {
      // Recycle waste back into stock, face down, preserving draw order.
      lastMovedCardIds = waste.map((c) => c.id).toSet();
      stock = waste.reversed.map((c) => c..faceUp = false).toList();
      waste = [];
      passes++;
      score = _clampScore(score - (drawCount == 1 ? 100 : 20));
    } else {
      final n = drawCount.clamp(0, stock.length);
      final drawn = <String>{};
      for (var i = 0; i < n; i++) {
        final card = stock.removeLast();
        card.faceUp = true;
        waste.add(card);
        drawn.add(card.id);
      }
      lastMovedCardIds = drawn;
    }
    selection = null;
    activeHint = null;
    moves++;
    _changed();
  }

  static int _clampScore(int value) => value < 0 ? 0 : value;

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
    if (pile.isEmpty) {
      if (card.rank != 1) return false;
      // A suit already has a home; don't let it start a second one.
      return !foundations.any((p) => p.isNotEmpty && p.first.suit == card.suit);
    }
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
      case PileType.waste:
        return false;
      case PileType.foundation:
        if (sel.cards.length != 1) return false;
        return _canPlaceOnFoundation(sel.cards.single, dest.index);
      case PileType.tableau:
        return _canPlaceOnTableau(sel.cards, dest.index);
    }
  }

  /// Every pile that would accept the cards currently being dragged or
  /// tap-selected, so the board can preview them all at once.
  Set<PileId> get activeDropTargets {
    final sel = dragging ?? selection;
    if (sel == null) return const {};
    final result = <PileId>{};
    for (var i = 0; i < 4; i++) {
      final id = PileId.foundation(i);
      if (canMove(sel, id)) result.add(id);
    }
    for (var i = 0; i < 7; i++) {
      final id = PileId.tableau(i);
      if (canMove(sel, id)) result.add(id);
    }
    return result;
  }

  void setDragging(CardSelection? sel) {
    dragging = sel;
    if (sel != null) {
      selection = null;
      activeHint = null;
    }
    notifyListeners();
  }

  /// Attempts to find *any* foundation pile that will accept this single
  /// card, used for the double-tap send-to-foundation gesture.
  PileId? autoFoundationTarget(PlayingCard card) {
    for (var i = 0; i < 4; i++) {
      if (_canPlaceOnFoundation(card, i)) return PileId.foundation(i);
    }
    return null;
  }

  int _scoreFor(CardSelection sel, PileId dest, {required bool revealed}) {
    var delta = 0;
    if (dest.type == PileType.foundation) delta += 10;
    if (sel.source.type == PileType.foundation &&
        dest.type == PileType.tableau) {
      delta -= 15;
    }
    if (sel.source.type == PileType.waste && dest.type == PileType.tableau) {
      delta += 5;
    }
    if (revealed) delta += 5;
    return delta;
  }

  /// Executes a validated move. Caller must have already confirmed
  /// [canMove] (or be [tryMove], which checks first).
  void _executeMove(CardSelection sel, PileId dest) {
    _pushUndo();
    _startClock();
    final source = pileFor(sel.source);
    source.removeRange(sel.cardIndex, source.length);
    var revealed = false;
    if (sel.source.type == PileType.tableau &&
        source.isNotEmpty &&
        !source.last.faceUp) {
      source.last.faceUp = true;
      revealed = true;
    }
    pileFor(dest).addAll(sel.cards);
    lastMovedCardIds = sel.cards.map((c) => c.id).toSet();
    score = _clampScore(score + _scoreFor(sel, dest, revealed: revealed));
    moves++;
    selection = null;
    activeHint = null;
    _checkWin();
    _changed();
  }

  bool tryMove(CardSelection sel, PileId dest) {
    if (!canMove(sel, dest)) return false;
    _executeMove(sel, dest);
    return true;
  }

  void _checkWin() {
    final complete = foundations.every((p) => p.length == 13);
    if (complete && !won) {
      won = true;
      _clock.stop();
      score += timeBonus;
    }
  }

  /// Bonus points awarded on a win: the faster the finish, the bigger it is.
  int get timeBonus => (600 - elapsed.inSeconds).clamp(0, 600);

  // ---- Tap handling ----

  static const _doubleTapWindow = Duration(milliseconds: 400);
  String? _lastTapId;
  DateTime? _lastTapAt;

  /// Whether this tap on [card] is the second half of a double tap. Tracked
  /// by hand so single taps stay instant instead of waiting out Flutter's
  /// built-in double-tap timeout.
  bool _isDoubleTap(PlayingCard card) {
    final now = DateTime.now();
    final isDouble = _lastTapId == card.id &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < _doubleTapWindow;
    _lastTapId = isDouble ? null : card.id;
    _lastTapAt = isDouble ? null : now;
    return isDouble;
  }

  /// Handles a tap on a specific card. A single tap picks the card up (or
  /// drops the current selection onto it); a double tap sends it straight to
  /// a foundation when it fits.
  void tapCard(PileId pileId, int cardIndex) {
    final pile = pileFor(pileId);
    if (cardIndex < 0 || cardIndex >= pile.length) return;
    final card = pile[cardIndex];

    if (_isDoubleTap(card) &&
        card.faceUp &&
        pileId.type != PileType.foundation &&
        isTopCard(pileId, cardIndex)) {
      final target = autoFoundationTarget(card);
      if (target != null) {
        _executeMove(CardSelection(pileId, cardIndex, [card]), target);
        return;
      }
    }

    final current = selection;
    if (current == null) {
      final stack = movableStack(pileId, cardIndex);
      if (stack != null) {
        selection = stack;
        activeHint = null;
        notifyListeners();
      }
      return;
    }

    if (current.source == pileId && current.cardIndex == cardIndex) {
      selection = null;
      notifyListeners();
      return;
    }

    if (tryMove(current, pileId)) return;
    selection = movableStack(pileId, cardIndex);
    notifyListeners();
  }

  /// Handles a tap on empty pile space (no cards to index into).
  void tapEmptyPile(PileId pileId) {
    final current = selection;
    if (current == null) return;
    if (tryMove(current, pileId)) return;
    selection = null;
    notifyListeners();
  }

  void clearSelection() {
    if (selection != null) {
      selection = null;
      notifyListeners();
    }
  }

  void clearHint() {
    if (activeHint != null) {
      activeHint = null;
      notifyListeners();
    }
  }

  // ---- Autoplay / solve ----

  /// Highest rank already banked for [suit], or 0 if that foundation is
  /// still empty.
  int foundationRank(Suit suit) {
    for (final pile in foundations) {
      if (pile.isNotEmpty && pile.first.suit == suit) return pile.last.rank;
    }
    return 0;
  }

  /// A card is "safe" to send up automatically when no card still buried in
  /// the tableau could plausibly need it as a landing spot: both opposite
  /// colours are within one rank, and its own colour within two.
  bool isSafeToAutoplay(PlayingCard card) {
    if (card.rank <= 2) return true;
    const reds = [Suit.hearts, Suit.diamonds];
    const blacks = [Suit.spades, Suit.clubs];
    final opposite = card.isRed ? blacks : reds;
    final sameColour = (card.isRed ? reds : blacks).where((s) => s != card.suit);
    for (final s in opposite) {
      if (foundationRank(s) < card.rank - 1) return false;
    }
    for (final s in sameColour) {
      if (foundationRank(s) < card.rank - 2) return false;
    }
    return true;
  }

  /// True once nothing is face down in the tableau, at which point every
  /// remaining card can be banked and the outcome is no longer in doubt.
  bool get canFinish => !won && tableau.every((p) => p.every((c) => c.faceUp));

  /// The exposed cards that could be sent to a foundation right now.
  List<Move> foundationMoves({required bool safeOnly}) {
    final result = <Move>[];
    void consider(PileId pileId, List<PlayingCard> pile) {
      if (pile.isEmpty) return;
      final card = pile.last;
      if (!card.faceUp) return;
      if (safeOnly && !isSafeToAutoplay(card)) return;
      final target = autoFoundationTarget(card);
      if (target != null) {
        result.add(Move(CardSelection(pileId, pile.length - 1, [card]), target));
      }
    }

    consider(PileId.waste, waste);
    for (var i = 0; i < 7; i++) {
      consider(PileId.tableau(i), tableau[i]);
    }
    // Lowest rank first so the foundations climb evenly.
    result.sort((a, b) =>
        a.selection.cards.single.rank.compareTo(b.selection.cards.single.rank));
    return result;
  }

  /// True when pressing Solve would actually accomplish something.
  bool get canSolve =>
      !won &&
      (foundationMoves(safeOnly: !canFinish).isNotEmpty || _finishNeedsDraw);

  /// During the finish sweep, whether cycling the stock would surface a card
  /// the foundations can take. Guards the solve loop against spinning
  /// through the stock forever.
  bool get _finishNeedsDraw =>
      canFinish &&
      (stock.isNotEmpty || waste.isNotEmpty) &&
      reachableWasteTops().any((c) => autoFoundationTarget(c) != null);

  /// Performs a single step of the solve, returning false when there is
  /// nothing left to do. The caller drives this on a timer so the cascade is
  /// visible, and wraps the run in [beginBatch]/[endBatch] so the whole thing
  /// undoes as one step.
  bool solveStep() {
    if (won) return false;
    final available = foundationMoves(safeOnly: !canFinish);
    if (available.isNotEmpty) {
      _executeMove(available.first.selection, available.first.dest);
      return true;
    }
    if (_finishNeedsDraw) {
      tapStock();
      return true;
    }
    return false;
  }

  // ---- Hints / stuck detection ----

  /// Every card that can be brought to the top of the waste by drawing and
  /// recycling from the current position. Simulated on copies of the piles,
  /// so it never touches live state.
  List<PlayingCard> reachableWasteTops() {
    var s = List<PlayingCard>.from(stock);
    var w = List<PlayingCard>.from(waste);
    final out = <PlayingCard>[];
    final seen = <String>{};
    if (w.isNotEmpty) out.add(w.last);
    for (var i = 0; i < 200; i++) {
      final sig = '${s.length}|${w.length}|${w.isEmpty ? '-' : w.last.id}';
      if (!seen.add(sig)) break;
      if (s.isEmpty) {
        if (w.isEmpty) break;
        s = w.reversed.toList();
        w = [];
      } else {
        final n = drawCount.clamp(0, s.length);
        for (var j = 0; j < n; j++) {
          w.add(s.removeLast());
        }
      }
      if (w.isNotEmpty) out.add(w.last);
    }
    return out;
  }

  bool _revealsCard(Move m) {
    if (m.selection.source.type != PileType.tableau) return false;
    final i = m.selection.cardIndex;
    if (i == 0) return false;
    return !tableau[m.selection.source.index][i - 1].faceUp;
  }

  /// Tableau-to-tableau moves worth suggesting: ones that uncover a face-down
  /// card or free up a column. Shuffling a run between two columns for no
  /// gain is deliberately excluded, otherwise the hint button would loop.
  List<Move> _usefulTableauMoves() {
    final result = <Move>[];
    for (var from = 0; from < 7; from++) {
      final pile = tableau[from];
      if (pile.isEmpty) continue;
      final firstFaceUp = pile.indexWhere((c) => c.faceUp);
      if (firstFaceUp < 0) continue;
      for (var i = firstFaceUp; i < pile.length; i++) {
        final sel = movableStack(PileId.tableau(from), i);
        if (sel == null) continue;
        final wouldReveal = i > 0 && !pile[i - 1].faceUp;
        final emptiesColumn = i == 0;
        for (var to = 0; to < 7; to++) {
          if (to == from) continue;
          if (!canMove(sel, PileId.tableau(to))) continue;
          // Relocating a whole column into another empty column is a no-op.
          final useful =
              wouldReveal || (emptiesColumn && tableau[to].isNotEmpty);
          if (!useful) continue;
          result.add(Move(sel, PileId.tableau(to)));
        }
      }
    }
    return result;
  }

  List<Move> _wasteToTableauMoves() {
    if (waste.isEmpty) return const [];
    final sel = CardSelection(PileId.waste, waste.length - 1, [waste.last]);
    return [
      for (var i = 0; i < 7; i++)
        if (canMove(sel, PileId.tableau(i))) Move(sel, PileId.tableau(i)),
    ];
  }

  /// Finds the most useful next action, in rough order of how much it helps.
  Hint? findHint() {
    if (won) return null;

    final safe = foundationMoves(safeOnly: true);
    if (safe.isNotEmpty) {
      return Hint(
        move: safe.first,
        description: 'Send ${safe.first.selection.cards.single} up',
      );
    }

    final useful = _usefulTableauMoves();
    final revealing = useful.where(_revealsCard).toList();
    if (revealing.isNotEmpty) {
      // Prefer the longest run, which digs the deepest column open.
      revealing.sort((a, b) =>
          b.selection.cards.length.compareTo(a.selection.cards.length));
      return Hint(
        move: revealing.first,
        description:
            'Move ${revealing.first.selection.cards.first} to uncover a card',
      );
    }

    final fromWaste = _wasteToTableauMoves();
    if (fromWaste.isNotEmpty) {
      return Hint(
        move: fromWaste.first,
        description: 'Play ${fromWaste.first.selection.cards.single} from the waste',
      );
    }

    if (useful.isNotEmpty) {
      return Hint(
        move: useful.first,
        description: 'Move ${useful.first.selection.cards.first} to free a column',
      );
    }

    final any = foundationMoves(safeOnly: false);
    if (any.isNotEmpty) {
      return Hint(
        move: any.first,
        description: 'Send ${any.first.selection.cards.single} up',
      );
    }

    if (_drawIsUseful) {
      return const Hint(description: 'Draw from the stock');
    }
    return null;
  }

  /// Whether cycling the stock can surface a card that is actually playable
  /// somewhere. Prevents "draw from the stock" being suggested forever on a
  /// dead board.
  bool get _drawIsUseful {
    if (stock.isEmpty && waste.isEmpty) return false;
    for (final card in reachableWasteTops()) {
      if (autoFoundationTarget(card) != null) return true;
      for (var i = 0; i < 7; i++) {
        if (_canPlaceOnTableau([card], i)) return true;
      }
    }
    return false;
  }

  /// True when there is genuinely nothing left to try.
  bool get isStuck => !won && findHint() == null;

  void showHint() {
    activeHint = findHint();
    notifyListeners();
  }

  // ---- Persistence ----

  Map<String, dynamic> toJson() => {
        'v': 1,
        'stock': stock.map((c) => c.toCode()).toList(),
        'waste': waste.map((c) => c.toCode()).toList(),
        'foundations':
            foundations.map((p) => p.map((c) => c.toCode()).toList()).toList(),
        'tableau': tableau.map((p) => p.map((c) => c.toCode()).toList()).toList(),
        'drawCount': drawCount,
        'moves': moves,
        'score': score,
        'passes': passes,
        'won': won,
        'elapsedMs': elapsed.inMilliseconds,
      };

  String encode() => jsonEncode(toJson());

  /// Restores a saved game. Returns false - leaving the current game intact -
  /// if the payload is missing, malformed, or not a complete 52-card deck.
  bool restore(String? encoded) {
    if (encoded == null || encoded.isEmpty) return false;
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      List<PlayingCard> parse(dynamic raw) => (raw as List)
          .map((e) => PlayingCardCodec.fromCode(e as int))
          .toList();

      final newStock = parse(data['stock']);
      final newWaste = parse(data['waste']);
      final newFoundations = (data['foundations'] as List).map(parse).toList();
      final newTableau = (data['tableau'] as List).map(parse).toList();
      if (newFoundations.length != 4 || newTableau.length != 7) return false;

      final all = [
        ...newStock,
        ...newWaste,
        ...newFoundations.expand((p) => p),
        ...newTableau.expand((p) => p),
      ];
      if (all.length != 52 || all.map((c) => c.id).toSet().length != 52) {
        return false;
      }

      stock = newStock;
      waste = newWaste;
      foundations = newFoundations;
      tableau = newTableau;
      drawCount = (data['drawCount'] as int?) == 3 ? 3 : 1;
      moves = (data['moves'] as int?) ?? 0;
      score = (data['score'] as int?) ?? 0;
      passes = (data['passes'] as int?) ?? 0;
      won = (data['won'] as bool?) ?? false;
      selection = null;
      dragging = null;
      activeHint = null;
      dealSerial++;
      animateDeal = false;
      lastMovedCardIds = const {};
      _undoStack.clear();
      _redoStack.clear();
      _batchDepth = 0;
      _resetClock();
      _clockBase = Duration(milliseconds: (data['elapsedMs'] as int?) ?? 0);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
