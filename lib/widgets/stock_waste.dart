import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'card_view.dart';
import 'drag_feedback.dart';

class StockPileWidget extends StatelessWidget {
  final GameState gameState;
  final double cardWidth;
  final double cardHeight;

  const StockPileWidget({super.key, required this.gameState, required this.cardWidth, required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    final isEmpty = gameState.stock.isEmpty;
    return GestureDetector(
      onTap: gameState.tapStock,
      child: CardView(
        card: isEmpty ? null : gameState.stock.last,
        width: cardWidth,
        height: cardHeight,
        emptySlotIcon: Icons.refresh,
      ),
    );
  }
}

class WastePileWidget extends StatelessWidget {
  final GameState gameState;
  final double cardWidth;
  final double cardHeight;

  const WastePileWidget({super.key, required this.gameState, required this.cardWidth, required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    final waste = gameState.waste;
    final visibleCount = waste.length.clamp(0, 3);
    final fanOffset = cardWidth * 0.28;
    final width = cardWidth + fanOffset * (visibleCount > 0 ? visibleCount - 1 : 0);

    return SizedBox(
      width: width == 0 ? cardWidth : width,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (waste.isEmpty) CardView(card: null, width: cardWidth, height: cardHeight),
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: fanOffset * i,
              child: _buildCard(waste.length - visibleCount + i),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(int index) {
    final pileId = PileId.waste;
    final cards = gameState.waste;
    final card = cards[index];
    final isTop = index == cards.length - 1;
    final selection = gameState.selection;
    final isSelected = selection != null && selection.source == pileId && selection.cardIndex == index;

    final view = CardView(card: card, width: cardWidth, height: cardHeight, selected: isSelected);

    if (!isTop) return view;

    return GestureDetector(
      onTap: () => gameState.tapCard(pileId, index),
      child: Draggable<CardSelection>(
        data: CardSelection(pileId, index, [card]),
        feedback: DragFeedback(cards: [card], cardWidth: cardWidth, cardHeight: cardHeight),
        childWhenDragging: Opacity(opacity: 0.25, child: view),
        onDragStarted: () => gameState.clearSelection(),
        child: view,
      ),
    );
  }
}
