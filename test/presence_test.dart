import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/widgets/squad/presence_indicator.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12, 0, 0);
  Presence at(Duration ago) => presenceFor(now.subtract(ago), now: now);

  group('presenceFor — boundaries', () {
    test('null → quiet "No activity yet"', () {
      final p = presenceFor(null, now: now);
      expect(p.label, 'No activity yet');
      expect(p.tier, PresenceTier.quiet);
    });

    test('< 5 min → Active now', () {
      expect(at(const Duration(minutes: 2)).label, 'Active now');
      expect(at(const Duration(minutes: 2)).activeNow, isTrue);
      expect(at(const Duration(minutes: 4, seconds: 59)).label, 'Active now');
    });

    test('5 min boundary → minutes', () {
      expect(at(const Duration(minutes: 5)).label, '5 min ago');
      expect(at(const Duration(minutes: 5)).tier, PresenceTier.recent);
      expect(at(const Duration(minutes: 59)).label, '59 min ago');
    });

    test('1 hour boundary → hours', () {
      expect(at(const Duration(minutes: 60)).label, '1 hour ago');
      expect(at(const Duration(hours: 5)).label, '5 hours ago');
      expect(at(const Duration(hours: 23)).label, '23 hours ago');
      expect(at(const Duration(minutes: 60)).tier, PresenceTier.today);
    });

    test('24 hour boundary → days', () {
      expect(at(const Duration(hours: 24)).label, '1 day ago');
      expect(at(const Duration(days: 3)).label, '3 days ago');
      expect(at(const Duration(days: 6)).label, '6 days ago');
      expect(at(const Duration(days: 6)).tier, PresenceTier.thisWeek);
    });

    test('7 day boundary → Quiet', () {
      expect(at(const Duration(days: 7)).label, 'Quiet 7 days');
      expect(at(const Duration(days: 7)).tier, PresenceTier.quiet);
      expect(at(const Duration(days: 30)).label, 'Quiet 30 days');
    });

    test('a future timestamp clamps to Active now', () {
      expect(presenceFor(now.add(const Duration(minutes: 10)), now: now).activeNow, isTrue);
    });
  });
}
