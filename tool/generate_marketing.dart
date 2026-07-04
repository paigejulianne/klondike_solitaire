// Generates Play Store marketing assets using Flutter's Canvas. Real text is
// rendered by loading a Windows system font (Segoe UI) into the test engine.
//
//   flutter test tool/generate_marketing.dart
//
// Outputs into assets/store/:
//   feature_graphic.png          1024x500 Play Store feature graphic
//   phone_1.png .. phone_N.png   framed phone screenshots  (from assets/store/raw/phone_*.png)
//   tablet_1.png .. tablet_N.png framed tablet screenshots (from assets/store/raw/tablet_*.png)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _green1 = Color(0xFF12902F);
const _green2 = Color(0xFF063D15);

// ---------------------------------------------------------------------------
// Shared drawing (card motif, matching the app icon).
// ---------------------------------------------------------------------------

void _fillGradient(Canvas canvas, Rect rect) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_green1, _green2],
      ).createShader(rect),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(rect.center.dx, rect.center.dy),
        rect.longestSide * 0.6,
        [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.0)],
      ),
  );
}

Path _spadePath(double size) {
  final p = Path();
  double x(double u) => u * size;
  double y(double v) => v * size;
  p.moveTo(x(0.5), y(0.06));
  p.cubicTo(x(0.60), y(0.30), x(1.02), y(0.44), x(1.0), y(0.66));
  p.cubicTo(x(0.99), y(0.82), x(0.85), y(0.90), x(0.71), y(0.88));
  p.cubicTo(x(0.63), y(0.87), x(0.57), y(0.83), x(0.53), y(0.78));
  p.cubicTo(x(0.55), y(0.86), x(0.60), y(0.95), x(0.70), y(0.985));
  p.lineTo(x(0.30), y(0.985));
  p.cubicTo(x(0.40), y(0.95), x(0.45), y(0.86), x(0.47), y(0.78));
  p.cubicTo(x(0.43), y(0.83), x(0.37), y(0.87), x(0.29), y(0.88));
  p.cubicTo(x(0.15), y(0.90), x(0.01), y(0.82), x(0.0), y(0.66));
  p.cubicTo(x(-0.02), y(0.44), x(0.40), y(0.30), x(0.5), y(0.06));
  p.close();
  return p;
}

void _drawCard(Canvas canvas, Offset center, double w, double h, double angleDeg, {required bool back}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angleDeg * 3.1415926535 / 180.0);
  final rrect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    Radius.circular(w * 0.12),
  );
  canvas.drawRRect(
    rrect.shift(const Offset(0, 12)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(w * 0.08), Radius.circular(w * 0.08)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  } else {
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    final spadeSize = w * 0.62;
    final spade = _spadePath(spadeSize);
    canvas.save();
    canvas.translate(-spadeSize / 2, -spadeSize * 0.55);
    canvas.drawPath(spade, Paint()..color = const Color(0xFF16181C));
    canvas.restore();
    final cs = w * 0.16;
    canvas.save();
    canvas.translate(-w * 0.40, -h * 0.42);
    canvas.drawPath(_spadePath(cs), Paint()..color = const Color(0xFF16181C));
    canvas.restore();
  }
  canvas.restore();
}

void _drawFannedCards(Canvas canvas, Offset center, double cardW) {
  final cardH = cardW * 1.4;
  _drawCard(canvas, center + Offset(-cardW * 0.28, cardH * 0.02), cardW, cardH, -16, back: true);
  _drawCard(canvas, center + Offset(cardW * 0.16, 0), cardW, cardH, 7, back: false);
}

// ---------------------------------------------------------------------------
// Text helpers.
// ---------------------------------------------------------------------------

void _text(
  Canvas canvas,
  String s,
  Offset pos,
  double size,
  Color color, {
  String family = 'Mk',
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
  List<Shadow> shadows = const [],
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: color, fontSize: size, fontFamily: family, height: 1.05, shadows: shadows),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  );
  tp.layout(maxWidth: maxWidth);
  tp.paint(canvas, pos);
}

Future<Uint8List> _render(int w, int h, void Function(Canvas, Size) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(w.toDouble(), h.toDouble()));
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image?> _loadImage(String path) async {
  final f = File(path);
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<void> _loadFont(String family, String file) async {
  final path = 'C:/Windows/Fonts/$file';
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

// Draws a device screenshot into a framed marketing image with a caption.
void _drawFramedShot(Canvas canvas, Size size, ui.Image shot, String caption) {
  _fillGradient(canvas, Offset.zero & size);
  // Caption band at the top.
  _text(
    canvas,
    caption,
    Offset(size.width * 0.08, size.height * 0.045),
    size.width * 0.058,
    Colors.white,
    family: 'MkB',
    maxWidth: size.width * 0.84,
    align: TextAlign.center,
    shadows: const [Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
  );
  // Device screenshot, scaled to fit below the caption with a rounded frame + shadow.
  final topPad = size.height * 0.16;
  final sidePad = size.width * 0.10;
  final avail = Rect.fromLTWH(sidePad, topPad, size.width - sidePad * 2, size.height - topPad - size.height * 0.05);
  final shotAspect = shot.width / shot.height;
  double dw = avail.width, dh = dw / shotAspect;
  if (dh > avail.height) {
    dh = avail.height;
    dw = dh * shotAspect;
  }
  final dst = Rect.fromCenter(center: Offset(size.width / 2, topPad + avail.height / 2), width: dw, height: dh);
  final radius = Radius.circular(dw * 0.06);
  final rrect = RRect.fromRectAndRadius(dst, radius);
  canvas.drawRRect(
    rrect.shift(const Offset(0, 14)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
  );
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawImageRect(
    shot,
    Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dw * 0.008
      ..color = Colors.white.withValues(alpha: 0.5),
  );
}

const _phoneCaptions = [
  'Classic Klondike Solitaire',
  'Drag or tap — your choice',
  'Draw 1 or 3, with undo',
];
const _tabletCaptions = [
  'Beautiful on tablets',
  'Play the way you like',
];

void main() {
  testWidgets('generate marketing assets', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('Mk', 'segoeui.ttf');
      await _loadFont('MkB', 'segoeuib.ttf');
      Directory('assets/store').createSync(recursive: true);

      // ---- Feature graphic (1024x500) ----
      final feature = await _render(1024, 500, (c, s) {
        _fillGradient(c, Offset.zero & s);
        _drawFannedCards(c, Offset(s.width * 0.80, s.height * 0.5), s.width * 0.20);
        _text(
          c,
          'Klondike',
          Offset(s.width * 0.06, s.height * 0.24),
          s.height * 0.20,
          Colors.white,
          family: 'MkB',
          shadows: const [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))],
        );
        _text(
          c,
          'Solitaire',
          Offset(s.width * 0.06, s.height * 0.44),
          s.height * 0.20,
          const Color(0xFFFFE08A),
          family: 'MkB',
          shadows: const [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))],
        );
        _text(
          c,
          'Play on phone, tablet & PC',
          Offset(s.width * 0.065, s.height * 0.70),
          s.height * 0.072,
          Colors.white.withValues(alpha: 0.95),
          family: 'Mk',
        );
      });
      File('assets/store/feature_graphic.png').writeAsBytesSync(feature);

      // ---- Framed screenshots (from assets/store/raw/) ----
      Future<void> frameSet(String prefix, List<String> captions, int w, int h) async {
        for (var i = 1; i <= captions.length; i++) {
          final shot = await _loadImage('assets/store/raw/${prefix}_$i.png');
          if (shot == null) continue;
          final png = await _render(w, h, (c, s) => _drawFramedShot(c, s, shot, captions[i - 1]));
          File('assets/store/${prefix}_$i.png').writeAsBytesSync(png);
        }
      }

      await frameSet('phone', _phoneCaptions, 1080, 1920);
      await frameSet('tablet', _tabletCaptions, 1920, 1200);

      expect(File('assets/store/feature_graphic.png').existsSync(), isTrue);
    });
  });
}
