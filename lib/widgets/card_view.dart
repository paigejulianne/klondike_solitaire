import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../models/card.dart';
import 'app_theme_scope.dart';

/// A ring drawn around a card to say something about it: a soft one for
/// "this is a legal drop target", a bright one for "you are hovering here",
/// amber for a hint.
@immutable
class CardAccent {
  final Color color;
  final double width;
  final double glow;

  const CardAccent({required this.color, this.width = 2, this.glow = 0});

  static const validTarget =
      CardAccent(color: Color(0xAA69F0AE), width: 2.5, glow: 8);
  static const hoverTarget =
      CardAccent(color: Color(0xFF69F0AE), width: 4, glow: 20);
  static const hint = CardAccent(color: Color(0xFFFFD54F), width: 4, glow: 18);
}

class CardView extends StatelessWidget {
  final PlayingCard? card;
  final double width;
  final double height;
  final bool selected;
  final bool isEmptySlot;
  final IconData? emptySlotIcon;
  final CardBackStyle? backStyleOverride;
  final CardAccent? accent;

  /// Forces the face or back to be drawn regardless of the card's own state.
  /// Used by the flip animation to show the old side through the first half
  /// of the turn.
  final bool? faceUpOverride;

  const CardView({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.selected = false,
    this.isEmptySlot = false,
    this.emptySlotIcon,
    this.backStyleOverride,
    this.accent,
    this.faceUpOverride,
  });

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.09;
    final accent = this.accent;

    if (card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: accent?.color ?? Colors.white24,
            width: accent?.width ?? 1.5,
          ),
          color: accent == null
              ? Colors.white.withValues(alpha: 0.06)
              : accent.color.withValues(alpha: 0.16),
          boxShadow: accent == null || accent.glow == 0
              ? null
              : [
                  BoxShadow(
                    color: accent.color.withValues(alpha: 0.55),
                    blurRadius: accent.glow,
                    spreadRadius: accent.glow * 0.15,
                  ),
                ],
        ),
        child: emptySlotIcon == null
            ? null
            : Center(
                child: Icon(emptySlotIcon, color: Colors.white24, size: width * 0.5),
              ),
      );
    }

    final backStyle = backStyleOverride ?? AppThemeScope.of(context).cardBackStyle;
    final showFace = faceUpOverride ?? card!.faceUp;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.5 : 0.3),
            blurRadius: selected ? 8 : 3,
            offset: const Offset(1, 2),
          ),
          if (accent != null && accent.glow > 0)
            BoxShadow(
              color: accent.color.withValues(alpha: 0.7),
              blurRadius: accent.glow,
              spreadRadius: accent.glow * 0.15,
            ),
        ],
        border: accent != null
            ? Border.all(color: accent.color, width: accent.width)
            : selected
                ? Border.all(color: Colors.amberAccent, width: 3)
                : null,
      ),
      child: showFace
          ? _CardFace(card: card!, width: width, height: height)
          : _CardBack(width: width, height: height, radius: radius, style: backStyle),
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
  final CardBackStyle style;
  const _CardBack({required this.width, required this.height, required this.radius, required this.style});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: width * 0.06),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DiamondLatticePainter(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            Container(
              padding: EdgeInsets.all(width * 0.14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Icon(style.icon, color: Colors.white70, size: width * 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// A repeating diamond-lattice pattern, like a classic playing card back.
class _DiamondLatticePainter extends CustomPainter {
  final Color color;
  const _DiamondLatticePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 12.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondLatticePainter oldDelegate) => oldDelegate.color != color;
}
