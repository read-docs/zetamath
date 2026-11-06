// Draws the launcher icon from the web logo (a keycap holding a zeta) and writes every Android
// density. Not part of the suite: run `fvm flutter test test/screens/icon_test.dart --dart-define=ICONS=android/app/src/main/res`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/themes/themes.dart';

const out = String.fromEnvironment('ICONS');
const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
final theme = themes['iceberg']!;

/// The web `LogoMark` (viewBox 44 × 32), centred in [box] at [width] logical units wide.
void paintLogo(Canvas canvas, Size box, double width, Color color) {
  final scale = width / 44;
  canvas.save();
  canvas.translate((box.width - width) / 2, (box.height - 32 * scale) / 2);
  canvas.scale(scale);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 40, 28), const Radius.circular(7)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color,
  );
  // Slightly larger and heavier than on web, so the glyph holds up at launcher size.
  // A stroke over the fill adds weight the variable font's axis alone doesn't give here.
  TextPainter zeta(Paint paint) => TextPainter(
    text: TextSpan(
      text: 'ζ',
      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 21, fontWeight: FontWeight.w700, foreground: paint),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final fill = zeta(Paint()..color = color);
  final stroke = zeta(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );
  // Web puts the baseline at y = 23 for a 19 px glyph; the larger glyph sits a little lower.
  final baseline = fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  for (final p in [fill, stroke]) {
    p.paint(canvas, Offset(22 - p.width / 2, 23.6 - baseline));
  }
  canvas.restore();
}

Future<void> writePng(String path, int px, void Function(Canvas, Size) paint) async {
  final recorder = ui.PictureRecorder();
  final size = Size(px.toDouble(), px.toDouble());
  paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('launcher icons', () async {
    if (out.isEmpty) return;
    final loader = FontLoader('JetBrains Mono')
      ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/JetBrainsMono.ttf').readAsBytesSync())));
    await loader.load();

    for (final MapEntry(key: name, value: d) in densities.entries) {
      // Adaptive foreground: 108 dp canvas, logo kept inside the 66 dp safe circle.
      await writePng('$out/mipmap-$name/ic_launcher_foreground.png', (108 * d).round(), (c, s) {
        paintLogo(c, s, 52 * d, theme.main);
      });
      // Legacy icon for Android 7: 48 dp rounded square with the logo on the theme background.
      await writePng('$out/mipmap-$name/ic_launcher.png', (48 * d).round(), (c, s) {
        c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(10 * d)), Paint()..color = theme.bg);
        paintLogo(c, s, 34 * d, theme.main);
      });
    }
  });
}
