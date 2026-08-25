import 'package:flutter/material.dart';

import '../models/board_layout.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import 'animated_card_slot.dart';
import 'card_view.dart';
import 'drag_feedback.dart';

/// The table.
///
/// Every card is a single absolutely-positioned widget keyed by card
/// identity, so a move is just a change of coordinates and the slot animates
/// itself there. Drop zones sit above the cards as translucent hit areas -
/// translucent so taps still fall through to the card underneath.
class GameBoard extends StatefulWidget {
  final GameState gameState;
  const GameBoard({super.key, required this.gameState});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  /// The pile currently under the dragged cards, if any.
  final ValueNotifier<PileId?> _hover = ValueNotifier(null);

  late final AnimationController _pulse;

  static const _moveDuration = Duration(milliseconds: 190);
  static const _dealStagger = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      value: 1,
    );
    game.addListener(_syncPulse);
  }

  @override
  void didUpdateWidget(covariant GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameState != widget.gameState) {
      oldWidget.gameState.removeListener(_syncPulse);
      game.addListener(_syncPulse);
      _syncPulse();
    }
  }

  @override
  void dispose() {
    game.removeListener(_syncPulse);
    _pulse.dispose();
    _hover.dispose();
    super.dispose();
  }

  /// The hint ring only pulses while a hint is showing - left running, it
  /// would keep the app producing frames forever.
  void _syncPulse() {
    final wanted = game.activeHint != null;
    if (wanted == _pulse.isAnimating) return;
    if (wanted) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  GameState get game => widget.gameState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 8.0;
        final layout = BoardLayout.forViewport(
          viewport: Size(
            constraints.maxWidth - pad * 2,
            constraints.maxHeight - pad * 2,
          ),
          game: game,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: game.clearSelection,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(pad),
            child: SizedBox(
              width: layout.size.width,
              height: layout.size.height,
              child: ValueListenableBuilder<PileId?>(
                valueListenable: _hover,
                builder: (context, hovered, _) => AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => _buildBoard(layout, hovered),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoard(BoardLayout layout, PileId? hovered) {
    final targets = game.activeDropTargets;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._buildSlots(layout, targets, hovered),
        ..._buildCards(layout, targets, hovered),
        ..._buildHintRings(layout),
        _buildStockTapZone(layout),
        ..._buildDropZones(layout),
      ],
    );
  }

  CardAccent? _accentFor(PileId pile, Set<PileId> targets, PileId? hovered) {
    if (hovered == pile) return CardAccent.hoverTarget;
    if (targets.contains(pile)) return CardAccent.validTarget;
    return null;
  }

  // ---- Empty pile placeholders ----

  List<Widget> _buildSlots(
    BoardLayout layout,
    Set<PileId> targets,
    PileId? hovered,
  ) {
    Widget slot(PileId pile, IconData? icon, {VoidCallback? onTap}) {
      final origin = layout.slotOrigin(pile);
      return Positioned(
        left: origin.dx,
        top: origin.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () => game.tapEmptyPile(pile),
          child: CardView(
            card: null,
            width: layout.cardWidth,
            height: layout.cardHeight,
            emptySlotIcon: icon,
            accent: game.pileFor(pile).isEmpty
                ? _accentFor(pile, targets, hovered)
                : null,
          ),
        ),
      );
    }

    return [
      slot(PileId.stock, Icons.refresh, onTap: game.tapStock),
      slot(PileId.waste, null, onTap: game.clearSelection),
      for (var i = 0; i < 4; i++) slot(PileId.foundation(i), Icons.tag),
      for (var i = 0; i < 7; i++) slot(PileId.tableau(i), Icons.circle_outlined),
    ];
  }

  // ---- Cards ----

  List<Widget> _buildCards(
    BoardLayout layout,
    Set<PileId> targets,
    PileId? hovered,
  ) {
    final entries = <_CardEntry>[];
    void collect(PileId pile) {
      final cards = game.pileFor(pile);
      for (var i = 0; i < cards.length; i++) {
        entries.add(_CardEntry(pile, i, cards[i]));
      }
    }

    collect(PileId.stock);
    collect(PileId.waste);
    for (var i = 0; i < 4; i++) {
      collect(PileId.foundation(i));
    }
    for (var i = 0; i < 7; i++) {
      collect(PileId.tableau(i));
    }

    // Cards from the last move are drawn last so they fly over the board
    // rather than sliding underneath the columns they cross.
    final moved = game.lastMovedCardIds;
    final ordered = [
      ...entries.where((e) => !moved.contains(e.card.id)),
      ...entries.where((e) => moved.contains(e.card.id)),
    ];

    return [
      for (final entry in ordered) _buildCard(entry, layout, targets, hovered),
    ];
  }

  Widget _buildCard(
    _CardEntry entry,
    BoardLayout layout,
    Set<PileId> targets,
    PileId? hovered,
  ) {
    final pile = entry.pile;
    final index = entry.index;
    final card = entry.card;
    final isTop = index == game.pileFor(pile).length - 1;

    final selection = game.selection;
    final selected = selection != null &&
        selection.source == pile &&
        index >= selection.cardIndex;

    // The rest of a dragged run lives in its own widgets, so dim them to
    // match the Draggable's own childWhenDragging.
    final drag = game.dragging;
    final dimmed = drag != null &&
        drag.source == pile &&
        index > drag.cardIndex &&
        pile.type == PileType.tableau;

    final hintCard = game.activeHint?.move?.selection;
    final isHintSource =
        hintCard != null && hintCard.source == pile && index == hintCard.cardIndex;

    CardAccent? accent;
    if (isTop) accent = _accentFor(pile, targets, hovered);
    if (isHintSource) {
      accent = CardAccent(
        color: CardAccent.hint.color.withValues(alpha: 0.4 + 0.6 * _pulse.value),
        width: CardAccent.hint.width,
        glow: CardAccent.hint.glow * _pulse.value,
      );
    }

    final lift = (isTop && hovered == pile) || selected ? 8.0 : 0.0;

    Widget content = FlipCard(
      faceUp: card.faceUp,
      builder: (context, showFace) => CardView(
        card: card,
        width: layout.cardWidth,
        height: layout.cardHeight,
        selected: selected,
        accent: accent,
        faceUpOverride: showFace,
      ),
    );

    if (dimmed) content = Opacity(opacity: 0.25, child: content);

    final movable = pile.type == PileType.stock || !card.faceUp
        ? null
        : game.movableStack(pile, index);

    Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: pile.type == PileType.stock
          ? game.tapStock
          : () => game.tapCard(pile, index),
      child: content,
    );

    if (movable != null) {
      interactive = Draggable<CardSelection>(
        data: movable,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: FractionalTranslation(
          translation: const Offset(-0.5, -0.25),
          child: DragFeedback(
            cards: movable.cards,
            cardWidth: layout.cardWidth,
            cardHeight: layout.cardHeight,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        onDragStarted: () => game.setDragging(movable),
        onDragEnd: (_) {
          _hover.value = null;
          game.setDragging(null);
        },
        child: interactive,
      );
    }

    final dealDelay = _dealDelayFor(entry);
    return AnimatedCardSlot(
      key: ValueKey('${game.dealSerial}:${card.id}'),
      position: layout.positionOf(pile, index, game),
      duration: _moveDuration,
      entryFrom: dealDelay == null ? null : layout.slotOrigin(PileId.stock),
      entryDelay: dealDelay ?? Duration.zero,
      lift: lift,
      child: interactive,
    );
  }

  /// Stagger for the opening deal, or null if this card shouldn't fly in.
  Duration? _dealDelayFor(_CardEntry entry) {
    if (!game.animateDeal) return null;
    if (entry.pile.type != PileType.tableau) return null;
    // Cards are dealt column by column, so this is the card's turn in line.
    final column = entry.pile.index;
    final order = column * (column + 1) ~/ 2 + entry.index;
    return _dealStagger * order;
  }

  // ---- Hint highlight ----

  List<Widget> _buildHintRings(BoardLayout layout) {
    final hint = game.activeHint;
    if (hint == null) return const [];

    final rect = hint.isDraw
        ? layout.slotOrigin(PileId.stock) & layout.cardSize
        : layout.dropRect(hint.move!.dest, game);

    return [
      Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.4 + 0.6 * _pulse.value,
            child: CustomPaint(
              painter: _GlowRingPainter(
                color: CardAccent.hint.color,
                radius: layout.cardWidth * 0.09,
                strokeWidth: 4,
                glow: 10,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ---- Hit areas ----

  /// Sits above the stock cards so a tap anywhere on the pile deals, whether
  /// or not any cards are left in it.
  Widget _buildStockTapZone(BoardLayout layout) {
    return Positioned.fromRect(
      rect: layout.slotOrigin(PileId.stock) & layout.cardSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: game.tapStock,
      ),
    );
  }

  List<Widget> _buildDropZones(BoardLayout layout) {
    Widget zone(PileId pile) => Positioned.fromRect(
          rect: layout.hitRect(pile, game),
          child: DragTarget<CardSelection>(
            onWillAcceptWithDetails: (details) => game.canMove(details.data, pile),
            onMove: (_) {
              if (_hover.value != pile) _hover.value = pile;
            },
            onLeave: (_) {
              if (_hover.value == pile) _hover.value = null;
            },
            onAcceptWithDetails: (details) {
              _hover.value = null;
              game.tryMove(details.data, pile);
            },
            builder: (context, candidate, rejected) => const SizedBox.expand(),
          ),
        );

    return [
      for (var i = 0; i < 4; i++) zone(PileId.foundation(i)),
      for (var i = 0; i < 7; i++) zone(PileId.tableau(i)),
    ];
  }
}

class _CardEntry {
  final PileId pile;
  final int index;
  final PlayingCard card;
  const _CardEntry(this.pile, this.index, this.card);
}

/// A glowing outline drawn as a stroke rather than a box shadow, so the card
/// inside stays legible - a BoxShadow on a container with no background
/// colour paints straight through the middle.
class _GlowRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double glow;

  const _GlowRingPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);

    if (glow > 0) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow;
}
