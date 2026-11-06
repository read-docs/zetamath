// Draws the launcher icon, the ζ from the web logo, and writes every Android
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

/// A bold ζ centred in [box]. [size] is the font size in pixels.
void paintZeta(Canvas canvas, Size box, double size, Color color) {
  // A stroke over the fill adds weight the variable font's axis alone doesn't give here.
  TextPainter zeta(Paint paint) => TextPainter(
    text: TextSpan(
      text: 'ζ',
      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: size, fontWeight: FontWeight.w700, foreground: paint),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final fill = zeta(Paint()..color = color);
  final stroke = zeta(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * .05
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );
  // The glyph's ink is centred about 0.28 em above its baseline (from its top serif to the tail).
  final baseline = fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final offset = Offset((box.width - fill.width) / 2, box.height / 2 + size * .28 - baseline);
  fill.paint(canvas, offset);
  stroke.paint(canvas, offset);
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
      // Adaptive foreground: 108 dp canvas, glyph kept inside the 66 dp safe circle.
      await writePng('$out/mipmap-$name/ic_launcher_foreground.png', (108 * d).round(), (c, s) {
        paintZeta(c, s, 52 * d, theme.main);
      });
      // Legacy icon for Android 7: 48 dp rounded square with the glyph on the theme background.
      await writePng('$out/mipmap-$name/ic_launcher.png', (48 * d).round(), (c, s) {
        c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(10 * d)), Paint()..color = theme.bg);
        paintZeta(c, s, 34 * d, theme.main);
      });
    }
  });
}
