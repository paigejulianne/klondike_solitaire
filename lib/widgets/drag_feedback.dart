import 'package:flutter/material.dart';

import '../models/card.dart';
import 'card_view.dart';

/// Visual shown under the pointer while dragging one or more cards.
class DragFeedback extends StatelessWidget {
  final List<PlayingCard> cards;
  final double cardWidth;
  final double cardHeight;

  const DragFeedback({super.key, required this.cards, required this.cardWidth, required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    final offset = cardHeight * 0.30;
    final height = cardHeight + offset * (cards.length - 1);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: cardWidth,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                top: offset * i,
                child: Opacity(
                  opacity: 0.9,
                  child: CardView(card: cards[i], width: cardWidth, height: cardHeight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
