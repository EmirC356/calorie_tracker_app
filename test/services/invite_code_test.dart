import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/invite_code.dart';

void main() {
  group('InviteCode', () {
    test('generate always returns a 6-digit numeric string', () {
      for (var seed = 0; seed < 200; seed++) {
        final code = InviteCode.generate(Random(seed));
        expect(code.length, 6, reason: 'seed $seed -> $code');
        expect(int.tryParse(code), isNotNull);
        expect(InviteCode.isValidFormat(code), isTrue);
      }
    });

    test('generate is deterministic for a seeded Random', () {
      expect(InviteCode.generate(Random(42)), InviteCode.generate(Random(42)));
    });

    test('isValidFormat accepts exactly 6 digits (trimmed), rejects others', () {
      expect(InviteCode.isValidFormat('123456'), isTrue);
      expect(InviteCode.isValidFormat('  123456 '), isTrue);
      expect(InviteCode.isValidFormat('12345'), isFalse);
      expect(InviteCode.isValidFormat('1234567'), isFalse);
      expect(InviteCode.isValidFormat('12a456'), isFalse);
      expect(InviteCode.isValidFormat(''), isFalse);
    });

    test('expiryFrom is 7 days after the given time', () {
      final from = DateTime(2026, 6, 9, 12);
      expect(InviteCode.expiryFrom(from), DateTime(2026, 6, 16, 12));
    });
  });
}
