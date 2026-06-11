import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image helpers for the Proof feature. Everything except [compressJpeg] is a
/// pure function (no IO, no plugins) so it can be unit-tested directly;
/// [compressJpeg] is the one thin wrapper over the native `flutter_image_compress`
/// plugin and is exercised on-device rather than in `flutter test`.

/// True if [b] begins with the JPEG SOI magic (FF D8 FF).
bool isJpeg(Uint8List b) =>
    b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

/// Reads (width, height) from a JPEG by walking its segment markers to the
/// first Start-Of-Frame (SOF0/1/2/…). Returns null if not a parseable JPEG.
({int width, int height})? readJpegDimensions(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    // SOF markers carry the frame dimensions — all of C0..CF except the
    // non-frame markers C4 (DHT), C8 (JPG), CC (DAC).
    final isSof = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      final height = (b[i + 5] << 8) | b[i + 6];
      final width = (b[i + 7] << 8) | b[i + 8];
      return (width: width, height: height);
    }
    if (i + 3 >= b.length) break;
    final segLen = (b[i + 2] << 8) | b[i + 3];
    if (segLen < 2) break;
    i += 2 + segLen;
  }
  return null;
}

/// Scales (w, h) down so neither side exceeds [maxDim], preserving the aspect
/// ratio. Returns the input unchanged when it already fits.
({int width, int height}) fittedSize(int w, int h, int maxDim) {
  if (w <= 0 || h <= 0) return (width: w, height: h);
  final longest = w > h ? w : h;
  if (longest <= maxDim) return (width: w, height: h);
  final scale = maxDim / longest;
  return (width: (w * scale).round(), height: (h * scale).round());
}

/// Compresses [input] to a JPEG that fits within [maxDim]×[maxDim] at the given
/// [quality]. The native plugin keeps aspect ratio; targets ~300 KB at the
/// defaults (1920px / q80). The only IO/plugin call in this file.
Future<Uint8List> compressJpeg(
  Uint8List input, {
  int maxDim = 1920,
  int quality = 80,
}) {
  return FlutterImageCompress.compressWithList(
    input,
    minWidth: maxDim,
    minHeight: maxDim,
    quality: quality,
    format: CompressFormat.jpeg,
  );
}
