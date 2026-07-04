// Renders the app icon to PNGs using Flutter's Canvas (no external image tools,
// no font dependency - the spade is a vector path). Run with:
//
//   flutter test tool/generate_app_icon.dart
//
// Outputs into assets/icon/:
//   app_icon.png            full-bleed master (gradient + fanned cards)
//   app_icon_foreground.png transparent, cards only (adaptive foreground)
//   app_icon_background.png gradient only (adaptive background)
//   play_store_512.png      512px master for the Play Store listing
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _green1 = Color(0xFF12902F);
const _green2 = Color(0xFF063D15);

void _drawBackground(Canvas canvas, double s) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_green1, _green2],
    ).createShader(rect);
  canvas.drawRect(rect, paint);
  // Soft radial glow in the centre to add depth.
  final glow = Paint()
    ..shader = ui.Gradient.radial(
      Offset(s * 0.5, s * 0.46),
      s * 0.55,
      [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.0)],
    );
  canvas.drawRect(rect, glow);
}

/// A spade shape inside a unit box, point at top. Filled by the caller.
Path _spadePath(double size) {
  final p = Path();
  double x(double u) => u * size;
  double y(double v) => v * size;
  p.moveTo(x(0.5), y(0.06));
  // right lobe
  p.cubicTo(x(0.60), y(0.30), x(1.02), y(0.44), x(1.0), y(0.66));
  p.cubicTo(x(0.99), y(0.82), x(0.85), y(0.90), x(0.71), y(0.88));
  p.cubicTo(x(0.63), y(0.87), x(0.57), y(0.83), x(0.53), y(0.78));
  // right half of stem
  p.cubicTo(x(0.55), y(0.86), x(0.60), y(0.95), x(0.70), y(0.985));
  p.lineTo(x(0.30), y(0.985));
  // left half of stem
  p.cubicTo(x(0.40), y(0.95), x(0.45), y(0.86), x(0.47), y(0.78));
  // left lobe
  p.cubicTo(x(0.43), y(0.83), x(0.37), y(0.87), x(0.29), y(0.88));
  p.cubicTo(x(0.15), y(0.90), x(0.01), y(0.82), x(0.0), y(0.66));
  p.cubicTo(x(-0.02), y(0.44), x(0.40), y(0.30), x(0.5), y(0.06));
  p.close();
  return p;
}

void _drawCard(
  Canvas canvas,
  Offset center,
  double w,
  double h,
  double angleDeg, {
  required bool back,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angleDeg * 3.1415926535 / 180.0);
  final rrect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    Radius.circular(w * 0.12),
  );
  // Drop shadow.
  canvas.drawRRect(
    rrect.shift(const Offset(0, 10)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
  );

  if (back) {
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C6BD6), Color(0xFF1B49A0)],
        ).createShader(r),
    );
    // White border ring on the card back.
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(w * 0.08), Radius.circular(w * 0.08)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  } else {
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015
        ..color = Colors.black.withValues(alpha: 0.15),
    );
    // Big centered spade.
    final spadeSize = w * 0.62;
    final spade = _spadePath(spadeSize);
    canvas.save();
    canvas.translate(-spadeSize / 2, -spadeSize * 0.55);
    canvas.drawPath(spade, Paint()..color = const Color(0xFF16181C));
    canvas.restore();
    // Small corner spade (top-left index).
    final cs = w * 0.16;
    final corner = _spadePath(cs);
    canvas.save();
    canvas.translate(-w * 0.40, -h * 0.42);
    canvas.drawPath(corner, Paint()..color = const Color(0xFF16181C));
    canvas.restore();
  }
  canvas.restore();
}

void _drawCards(Canvas canvas, double s, double scale) {
  final cardW = s * 0.40 * scale;
  final cardH = cardW * 1.4;
  final center = Offset(s * 0.5, s * 0.5);
  // Back card fanned behind to the left.
  _drawCard(
    canvas,
    center + Offset(-s * 0.10 * scale, s * 0.01),
    cardW,
    cardH,
    -16,
    back: true,
  );
  // Front card, slightly tilted the other way.
  _drawCard(
    canvas,
    center + Offset(s * 0.055 * scale, 0),
    cardW,
    cardH,
    7,
    back: false,
  );
}

Future<Uint8List> _renderPng(
  int size,
  void Function(Canvas canvas, double s) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size.toDouble());
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('generate app icon PNGs', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory('assets/icon');
      dir.createSync(recursive: true);

      // Master (full-bleed): gradient + cards.
      final master = await _renderPng(1024, (c, s) {
        _drawBackground(c, s);
        _drawCards(c, s, 1.0);
      });
      File('assets/icon/app_icon.png').writeAsBytesSync(master);

      // Play Store 512.
      final play = await _renderPng(512, (c, s) {
        _drawBackground(c, s);
        _drawCards(c, s, 1.0);
      });
      File('assets/icon/play_store_512.png').writeAsBytesSync(play);

      // Adaptive background: gradient only.
      final bg = await _renderPng(1024, (c, s) => _drawBackground(c, s));
      File('assets/icon/app_icon_background.png').writeAsBytesSync(bg);

      // Adaptive foreground: transparent, cards scaled down into the safe zone.
      final fg = await _renderPng(1024, (c, s) => _drawCards(c, s, 0.86));
      File('assets/icon/app_icon_foreground.png').writeAsBytesSync(fg);

      for (final name in [
        'app_icon.png',
        'play_store_512.png',
        'app_icon_background.png',
        'app_icon_foreground.png',
      ]) {
        final f = File('assets/icon/$name');
        expect(f.existsSync(), isTrue);
        expect(f.lengthSync(), greaterThan(0));
      }
    });
  });
}
