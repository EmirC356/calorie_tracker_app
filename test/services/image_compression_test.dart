import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/image_compression.dart';

void main() {
  group('isJpeg', () {
    test('accepts JPEG SOI magic', () {
      expect(isJpeg(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xC0])), isTrue);
    });
    test('rejects PNG / too-short', () {
      expect(isJpeg(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])), isFalse);
      expect(isJpeg(Uint8List.fromList([0xFF, 0xD8])), isFalse);
    });
  });

  group('readJpegDimensions', () {
    test('reads width/height from an SOF0 marker', () {
      // FF D8 (SOI) | FF C0 00 11 08 (SOF0, precision 8) | 01 E0 (h=480) 02 80 (w=640)
      final jpeg = Uint8List.fromList(
          [0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x01, 0xE0, 0x02, 0x80, 0x03, 0, 0, 0]);
      final size = readJpegDimensions(jpeg);
      expect(size, isNotNull);
      expect(size!.width, 640);
      expect(size.height, 480);
    });

    test('skips a leading APP0 segment to find the SOF', () {
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, len 4 → 2 data bytes
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x03, 0x20, 0x05, 0x00, 0x03, 0, 0, // SOF: h=800 w=1280
      ]);
      final size = readJpegDimensions(jpeg);
      expect(size!.height, 800);
      expect(size.width, 1280);
    });

    test('returns null for non-JPEG bytes', () {
      expect(readJpegDimensions(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), isNull);
    });
  });

  group('fittedSize', () {
    test('leaves an already-small image unchanged', () {
      expect(fittedSize(800, 600, 1920), (width: 800, height: 600));
      expect(fittedSize(1080, 1920, 1920), (width: 1080, height: 1920));
    });
    test('scales a 4K landscape down to maxDim on the long side', () {
      expect(fittedSize(3840, 2160, 1920), (width: 1920, height: 1080));
    });
    test('scales a very wide image by the long side', () {
      expect(fittedSize(4000, 1000, 1920), (width: 1920, height: 480));
    });
    test('handles a portrait over the limit', () {
      expect(fittedSize(2160, 3840, 1920), (width: 1080, height: 1920));
    });
  });
}
