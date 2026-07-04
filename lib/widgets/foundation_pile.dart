import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'card_view.dart';

class FoundationPile extends StatelessWidget {
  final GameState gameState;
  final int index;
  final double cardWidth;
  final double cardHeight;

  const FoundationPile({
    super.key,
    required this.gameState,
    required this.index,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final pileId = PileId.foundation(index);
    final cards = gameState.foundations[index];
    final top = cards.isEmpty ? null : cards.last;
    final selection = gameState.selection;
    final isSelected = selection != null && selection.source == pileId;

    return DragTarget<CardSelection>(
      onWillAcceptWithDetails: (details) => gameState.canMove(details.data, pileId),
      onAcceptWithDetails: (details) => gameState.tryMove(details.data, pileId),
      builder: (context, candidateData, rejectedData) {
        final highlight = candidateData.isNotEmpty;
        final view = CardView(
          card: top,
          width: cardWidth,
          height: cardHeight,
          selected: isSelected,
          emptySlotIcon: Icons.tag,
        );
        final decorated = highlight
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardWidth * 0.09),
                  border: Border.all(color: Colors.greenAccent, width: 3),
                ),
                child: view,
              )
            : view;

        return GestureDetector(
          onTap: () {
            if (top == null) {
              gameState.tapEmptyPile(pileId);
            } else {
              gameState.tapCard(pileId, cards.length - 1);
            }
          },
          child: top == null
              ? decorated
              : Draggable<CardSelection>(
                  data: CardSelection(pileId, cards.length - 1, [top]),
                  feedback: Material(color: Colors.transparent, child: view),
                  childWhenDragging: Opacity(opacity: 0.25, child: view),
                  onDragStarted: () => gameState.clearSelection(),
                  child: decorated,
                ),
        );
      },
    );
  }
}
