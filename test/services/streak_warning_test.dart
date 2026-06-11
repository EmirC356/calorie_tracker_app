import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/services/streak_warning_service.dart';

void main() {
  group('buildBody', () {
    test('nothing at risk → null', () {
      expect(StreakWarningService.buildBody([]), isNull);
    });

    test('a single squad names it and its streak', () {
      final body = StreakWarningService.buildBody([(squad: 'Gym Bros', streak: 7)]);
      expect(body, contains('7-day streak'));
      expect(body, contains('Gym Bros'));
    });

    test('multiple squads collapse into one message, max 3 named', () {
      final body = StreakWarningService.buildBody([
        (squad: 'A', streak: 3),
        (squad: 'B', streak: 4),
        (squad: 'C', streak: 5),
        (squad: 'D', streak: 6),
      ]);
      expect(body, contains('4 streaks at risk'));
      expect(body, contains('A, B, C'));
      expect(body, isNot(contains('D'))); // collapsed to the first 3
    });
  });
}
