import 'package:flutter/material.dart';

import '../models/card.dart';

class CardView extends StatelessWidget {
  final PlayingCard? card;
  final double width;
  final double height;
  final bool selected;
  final bool isEmptySlot;
  final IconData? emptySlotIcon;

  const CardView({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.selected = false,
    this.isEmptySlot = false,
    this.emptySlotIcon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.09;
    if (card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white24, width: 1.5),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: emptySlotIcon == null
            ? null
            : Center(
                child: Icon(emptySlotIcon, color: Colors.white24, size: width * 0.5),
              ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      transform: selected ? (Matrix4.identity()..translateByDouble(0.0, -8.0, 0.0, 1.0)) : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.5 : 0.3),
            blurRadius: selected ? 8 : 3,
            offset: const Offset(1, 2),
          ),
        ],
        border: selected ? Border.all(color: Colors.amberAccent, width: 3) : null,
      ),
      child: card!.faceUp ? _CardFace(card: card!, width: width, height: height) : _CardBack(width: width, height: height, radius: radius),
    );
  }
}

class _CardFace extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;
  const _CardFace({required this.card, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? Colors.red.shade700 : Colors.black87;
    final radius = width * 0.09;
    final fontSize = width * 0.24;
    final symbolSize = width * 0.4;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            left: width * 0.08,
            top: height * 0.04,
            child: _RankSuit(card: card, color: color, fontSize: fontSize),
          ),
          Positioned(
            right: width * 0.08,
            bottom: height * 0.04,
            child: Transform.rotate(
              angle: 3.14159,
              child: _RankSuit(card: card, color: color, fontSize: fontSize),
            ),
          ),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(color: color, fontSize: symbolSize, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankSuit extends StatelessWidget {
  final PlayingCard card;
  final Color color;
  final double fontSize;
  const _RankSuit({required this.card, required this.color, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          card.rankLabel,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1),
        ),
        Text(
          card.suit.symbol,
          style: TextStyle(color: color, fontSize: fontSize * 0.8, height: 1),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _CardBack({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: width * 0.06),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade800, Colors.blue.shade400],
        ),
      ),
      child: Center(
        child: Icon(Icons.style, color: Colors.white24, size: width * 0.45),
      ),
    );
  }
}
