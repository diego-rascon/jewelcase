// Regenerates every platform's app icon from DiscPainter:
//
//   flutter test tool/generate_icons.dart
//
// Each existing icon PNG is redrawn at its current pixel size, so the
// platform folders stay the single list of sizes each platform needs.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/ui/widgets/disc_logo.dart';
import 'package:material_ui/material_ui.dart';

enum _Frame {
  /// Square, edge to edge; the platform applies its own mask (iOS, maskable web icons).
  fullBleed(0.62),

  /// Rounded square filling the canvas (Windows, web, legacy Android).
  rounded(0.70),

  /// macOS template: an inset rounded square with room for its shadow.
  macos(0.56),

  /// Android adaptive-icon layers, kept inside the 66/108 dp safe zone.
  foreground(0.56),
  silhouette(0.56),
  backdrop(0);

  const _Frame(this.discScale);

  final double discScale;
}

const _backdrop = [Color(0xFF26262E), Color(0xFF0E0E11)];

void _paint(Canvas canvas, double s, _Frame frame) {
  final full = Offset.zero & Size.square(s);
  final plate = switch (frame) {
    _Frame.fullBleed || _Frame.backdrop => RRect.fromRectAndRadius(full, Radius.zero),
    _Frame.rounded => RRect.fromRectAndRadius(full, Radius.circular(s * 0.225)),
    _Frame.macos => RRect.fromRectAndRadius(
      Rect.fromCenter(center: full.center, width: s * 824 / 1024, height: s * 824 / 1024),
      Radius.circular(s * 185 / 1024),
    ),
    _Frame.foreground || _Frame.silhouette => null,
  };
  if (plate != null) {
    if (frame == _Frame.macos) {
      canvas.drawRRect(
        plate.shift(Offset(0, s * 0.01)),
        Paint()
          ..color = const Color(0x4D000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015),
      );
    }
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 0.9,
          colors: _backdrop,
        ).createShader(plate.outerRect),
    );
  }
  if (frame == _Frame.backdrop) return;

  final d = s * frame.discScale;
  final disc = Rect.fromCenter(center: full.center, width: d, height: d);
  if (frame != _Frame.silhouette) {
    canvas.drawCircle(
      disc.center + Offset(0, d * 0.03),
      d / 2,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.04),
    );
  }
  canvas
    ..save()
    ..translate(disc.left, disc.top);
  DiscPainter(silhouette: frame == _Frame.silhouette).paint(canvas, disc.size);
  canvas.restore();
}

Future<Uint8List> _render(int px, _Frame frame, {bool alpha = true}) async {
  final recorder = ui.PictureRecorder();
  _paint(Canvas(recorder), px.toDouble(), frame);
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  return _encodePng(data!.buffer.asUint8List(), px, px, alpha: alpha);
}

/// Width of a square PNG, read from its header.
int _pngSize(File file) => ByteData.sublistView(file.readAsBytesSync(), 16, 20).getUint32(0);

// ---- Encoders ---------------------------------------------------------------
//
// Hand-rolled so the generator needs no image package. iOS needs PNGs without
// an alpha channel, which Flutter's own PNG encoder can't produce.

Uint8List _encodePng(Uint8List rgba, int width, int height, {required bool alpha}) {
  final channels = alpha ? 4 : 3;
  final stride = width * channels;
  final raw = BytesBuilder(copy: false);
  var above = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final pixels = Uint8List(stride);
    for (var x = 0; x < width; x++) {
      pixels.setRange(x * channels, (x + 1) * channels, rgba, (y * width + x) * 4);
    }
    // Paeth filter: store each byte as the difference from its best-guess
    // neighbor, which makes the icons' smooth gradients compress far better.
    final row = Uint8List(1 + stride)..[0] = 4;
    for (var i = 0; i < stride; i++) {
      final a = i >= channels ? pixels[i - channels] : 0;
      final b = above[i];
      final c = i >= channels ? above[i - channels] : 0;
      final p = a + b - c;
      final (pa, pb, pc) = ((p - a).abs(), (p - b).abs(), (p - c).abs());
      final predictor = pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
      row[1 + i] = (pixels[i] - predictor) & 0xFF;
    }
    raw.add(row);
    above = pixels;
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // Bit depth.
    ..setUint8(9, alpha ? 6 : 2); // Color type: RGBA or RGB.
  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes())))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

Uint8List _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final out = ByteData(body.length + 8)..setUint32(0, data.length);
  final bytes = out.buffer.asUint8List()..setRange(4, 4 + body.length, body);
  out.setUint32(4 + body.length, _crc32(body));
  return bytes;
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// An .ico holding one PNG per size.
Uint8List _encodeIco(List<(int, Uint8List)> images) {
  final header = ByteData(6 + 16 * images.length)
    ..setUint16(2, 1, Endian.little) // Type: icon.
    ..setUint16(4, images.length, Endian.little);
  var offset = header.lengthInBytes;
  for (final (i, (px, png)) in images.indexed) {
    final e = 6 + 16 * i;
    header
      ..setUint8(e, px >= 256 ? 0 : px) // 0 means 256.
      ..setUint8(e + 1, px >= 256 ? 0 : px)
      ..setUint16(e + 4, 1, Endian.little) // Color planes.
      ..setUint16(e + 6, 32, Endian.little) // Bits per pixel.
      ..setUint32(e + 8, png.length, Endian.little)
      ..setUint32(e + 12, offset, Endian.little);
    offset += png.length;
  }
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add([for (final (_, png) in images) ...png]))
      .takeBytes();
}

// ---- Platforms --------------------------------------------------------------

Future<void> _redraw(String dir, _Frame frame, {bool alpha = true, bool Function(String name)? where}) async {
  for (final file in Directory(dir).listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.png') || (where != null && !where(name))) continue;
    file.writeAsBytesSync(await _render(_pngSize(file), frame, alpha: alpha));
  }
}

void main() {
  test('generate app icons', () async {
    await _redraw('ios/Runner/Assets.xcassets/AppIcon.appiconset', _Frame.fullBleed, alpha: false);
    await _redraw('macos/Runner/Assets.xcassets/AppIcon.appiconset', _Frame.macos);
    await _redraw('web/icons', _Frame.fullBleed, where: (n) => n.contains('maskable'));
    await _redraw('web/icons', _Frame.rounded, where: (n) => !n.contains('maskable'));
    await _redraw('web', _Frame.rounded, where: (n) => n == 'favicon.png');

    // Android: the legacy icon, plus adaptive-icon layers (108 dp for every
    // 48 dp of legacy icon) used by mipmap-anydpi-v26/ic_launcher.xml.
    final densities = Directory('android/app/src/main/res')
        .listSync()
        .whereType<Directory>()
        .where((d) => d.uri.pathSegments.any((s) => s.startsWith('mipmap-') && !s.contains('anydpi')));
    for (final dir in densities) {
      final legacy = File('${dir.path}/ic_launcher.png');
      final px = _pngSize(legacy);
      legacy.writeAsBytesSync(await _render(px, _Frame.rounded));
      final layer = px * 108 ~/ 48;
      for (final (name, frame) in [
        ('foreground', _Frame.foreground),
        ('background', _Frame.backdrop),
        ('monochrome', _Frame.silhouette),
      ]) {
        File('${dir.path}/ic_launcher_$name.png').writeAsBytesSync(await _render(layer, frame));
      }
    }

    File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
      _encodeIco([
        for (final px in const [16, 24, 32, 48, 64, 128, 256]) (px, await _render(px, _Frame.rounded)),
      ]),
    );
  });
}
