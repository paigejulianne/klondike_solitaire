import 'package:flutter/material.dart';

import '../models/card.dart';
import '../models/game_state.dart';
import 'card_view.dart';
import 'drag_feedback.dart';

class TableauColumn extends StatelessWidget {
  final GameState gameState;
  final int index;
  final double cardWidth;
  final double cardHeight;

  const TableauColumn({
    super.key,
    required this.gameState,
    required this.index,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final pileId = PileId.tableau(index);
    final cards = gameState.tableau[index];
    final faceDownOffset = cardHeight * 0.22;
    final faceUpOffset = cardHeight * 0.30;

    final tops = <double>[];
    var top = 0.0;
    for (final c in cards) {
      tops.add(top);
      top += c.faceUp ? faceUpOffset : faceDownOffset;
    }
    final totalHeight = cards.isEmpty ? cardHeight : (tops.last + cardHeight);

    return DragTarget<CardSelection>(
      onWillAcceptWithDetails: (details) => gameState.canMove(details.data, pileId),
      onAcceptWithDetails: (details) => gameState.tryMove(details.data, pileId),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (cards.isEmpty) gameState.tapEmptyPile(pileId);
          },
          child: SizedBox(
            width: cardWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CardView(
                  card: null,
                  width: cardWidth,
                  height: cardHeight,
                  emptySlotIcon: Icons.circle_outlined,
                  isEmptySlot: true,
                ),
                if (highlight)
                  Positioned(
                    top: cards.isEmpty ? 0 : tops.last,
                    child: Container(
                      width: cardWidth,
                      height: cards.isEmpty ? cardHeight : cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardWidth * 0.09),
                        color: Colors.greenAccent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    top: tops[i],
                    child: _TableauCard(
                      gameState: gameState,
                      pileId: pileId,
                      cardIndex: i,
                      card: cards[i],
                      cardWidth: cardWidth,
                      cardHeight: cardHeight,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableauCard extends StatelessWidget {
  final GameState gameState;
  final PileId pileId;
  final int cardIndex;
  final PlayingCard card;
  final double cardWidth;
  final double cardHeight;

  const _TableauCard({
    required this.gameState,
    required this.pileId,
    required this.cardIndex,
    required this.card,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final selection = gameState.selection;
    final isSelected = selection != null &&
        selection.source == pileId &&
        cardIndex >= selection.cardIndex;

    final view = CardView(
      card: card,
      width: cardWidth,
      height: cardHeight,
      selected: isSelected,
    );

    final movable = card.faceUp ? gameState.movableStack(pileId, cardIndex) : null;

    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => gameState.tapCard(pileId, cardIndex),
      child: view,
    );

    if (movable == null) return tappable;

    return Draggable<CardSelection>(
      data: movable,
      feedback: DragFeedback(cards: movable.cards, cardWidth: cardWidth, cardHeight: cardHeight),
      childWhenDragging: Opacity(opacity: 0.25, child: view),
      onDragStarted: () => gameState.clearSelection(),
      child: tappable,
    );
  }
}
