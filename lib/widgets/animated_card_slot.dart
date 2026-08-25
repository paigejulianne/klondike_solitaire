import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Positions a card on the board and glides it whenever its home changes.
///
/// Every move in the game is expressed as "this card now belongs somewhere
/// else"; this widget turns that into motion. Because cards are keyed by
/// identity, the same element survives the rebuild and animates instead of
/// jumping.
class AnimatedCardSlot extends StatefulWidget {
  final Offset position;
  final Duration duration;

  /// Where the card flies in from the first time it appears, used for the
  /// opening deal. Null means "start already in place".
  final Offset? entryFrom;

  /// Delay before the entry animation starts, so the deal staggers.
  final Duration entryDelay;

  /// Extra upward nudge, animated separately from the position so hover and
  /// selection feel snappy.
  final double lift;

  final Widget child;

  const AnimatedCardSlot({
    super.key,
    required this.position,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.entryFrom,
    this.entryDelay = Duration.zero,
    this.lift = 0,
  });

  @override
  State<AnimatedCardSlot> createState() => _AnimatedCardSlotState();
}

class _AnimatedCardSlotState extends State<AnimatedCardSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _offset;
  late Offset _target;

  @override
  void initState() {
    super.initState();
    _target = widget.position;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final from = widget.entryFrom;
    if (from != null && from != widget.position) {
      _animate(from, widget.position, delay: widget.entryDelay);
    } else {
      _offset = AlwaysStoppedAnimation(widget.position);
    }
  }

  void _animate(Offset from, Offset to, {Duration delay = Duration.zero}) {
    final total = delay + widget.duration;
    _controller
      ..stop()
      ..duration = total;
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    _offset = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start.clamp(0.0, 0.99), 1, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AnimatedCardSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != _target) {
      final current = _controller.isAnimating ? _offset.value : _target;
      _target = widget.position;
      _animate(current, widget.position);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        final p = _offset.value;
        return Positioned(left: p.dx, top: p.dy, child: child!);
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.lift),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        builder: (context, lift, child) =>
            Transform.translate(offset: Offset(0, -lift), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Turns a card over with a 3D flip when its face-up state changes.
class FlipCard extends StatefulWidget {
  final bool faceUp;
  final Duration duration;

  /// Builds the card showing either side; the flip swaps [showFace] at the
  /// halfway point, where the card is edge-on and the switch is invisible.
  final Widget Function(BuildContext context, bool showFace) builder;

  const FlipCard({
    super.key,
    required this.faceUp,
    required this.builder,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _showFace;

  @override
  void initState() {
    super.initState();
    _showFace = widget.faceUp;
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.faceUp != oldWidget.faceUp) {
      _showFace = oldWidget.faceUp;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final flipped = t >= 0.5 || t == 0;
        final showFace = flipped ? widget.faceUp : _showFace;
        // First half turns to edge-on; second half continues from edge-on to
        // flat, so the newly revealed side is never drawn mirrored.
        final angle = t == 0 ? 0.0 : (t < 0.5 ? t : t - 1) * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: widget.builder(context, showFace),
        );
      },
    );
  }
}
