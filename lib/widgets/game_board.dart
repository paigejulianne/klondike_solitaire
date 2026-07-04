import 'package:flutter/material.dart';

import '../models/game_state.dart';
import 'foundation_pile.dart';
import 'stock_waste.dart';
import 'tableau_column.dart';

class GameBoard extends StatelessWidget {
  final GameState gameState;
  const GameBoard({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 7;
        const spacing = 8.0;
        final availableWidth = constraints.maxWidth - spacing * (columns + 1);
        var cardWidth = availableWidth / columns;
        cardWidth = cardWidth.clamp(48.0, 110.0);
        final cardHeight = cardWidth * 1.42;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(spacing),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - spacing * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopRow(gameState: gameState, cardWidth: cardWidth, cardHeight: cardHeight, spacing: spacing),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 7; i++)
                      TableauColumn(
                        gameState: gameState,
                        index: i,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  final GameState gameState;
  final double cardWidth;
  final double cardHeight;
  final double spacing;

  const _TopRow({required this.gameState, required this.cardWidth, required this.cardHeight, required this.spacing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StockPileWidget(gameState: gameState, cardWidth: cardWidth, cardHeight: cardHeight),
            SizedBox(width: spacing * 2),
            WastePileWidget(gameState: gameState, cardWidth: cardWidth, cardHeight: cardHeight),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              FoundationPile(gameState: gameState, index: i, cardWidth: cardWidth, cardHeight: cardHeight),
            ],
          ],
        ),
      ],
    );
  }
}
