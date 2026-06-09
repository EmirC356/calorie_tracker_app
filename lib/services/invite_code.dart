import 'dart:math';

/// 6-digit numeric invite codes. Codes are random (not globally guaranteed
/// unique — collisions across ~10^6 codes are negligible for this app's scale;
/// join resolves via a `squadCodes/{code}` lookup doc, and a colliding code
/// simply points at whichever squad wrote it last).
class InviteCode {
  static const int length = 6;
  static final _fallback = Random.secure();

  /// Random code in [100000, 999999] so it is always 6 digits.
  static String generate([Random? random]) {
    final r = random ?? _fallback;
    return (100000 + r.nextInt(900000)).toString();
  }

  static bool isValidFormat(String code) =>
      RegExp(r'^\d{6}$').hasMatch(code.trim());

  /// 7 days from [from] (defaults to now).
  static DateTime expiryFrom([DateTime? from]) =>
      (from ?? DateTime.now()).add(const Duration(days: 7));
}
