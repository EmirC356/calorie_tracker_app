import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_activity.dart';

SquadActivity ev(String type,
        {String actor = 'Selin', String? subject, Map<String, dynamic> payload = const {}}) =>
    SquadActivity(id: 'x', type: type, actorName: actor, subjectName: subject, payload: payload);

void main() {
  group('SquadActivity.line — canonical types', () {
    test('goalHit', () => expect(ev('goalHit').line, 'Selin hit their goal'));
    test('streakMilestone',
        () => expect(ev('streakMilestone', payload: {'length': 14}).line, 'Selin hit a 14-day streak 🔥'));
    test('streakBroken',
        () => expect(ev('streakBroken', payload: {'length': 14}).line, "Selin's 14-day streak ended"));
    test('commentPosted',
        () => expect(ev('commentPosted', subject: 'Ali').line, "Selin commented on Ali's day"));
    test('reactionSent', () =>
        expect(ev('reactionSent', subject: 'Ali', payload: {'emoji': 'fire'}).line, 'Selin sent 🔥 to Ali'));
    test('pauseStarted',
        () => expect(ev('pauseStarted', payload: {'until': 'Sun'}).line, 'Selin paused until Sun'));
    test('pauseEnded', () => expect(ev('pauseEnded').line, 'Selin is back'));
    test('memberJoined', () => expect(ev('memberJoined').line, 'Selin joined the squad'));
    test('memberLeft', () => expect(ev('memberLeft').line, 'Selin left the squad'));
    test('intentionSet', () => expect(
        ev('intentionSet', payload: {'text': 'Gym 3x'}).line, 'Selin declared this week: "Gym 3x"'));
    test('fullSquadDay', () =>
        expect(ev('fullSquadDay', actor: '', payload: {'date': 'Mon Jun 15'}).line, '🔥 Full squad day on Mon Jun 15'));
    test('groupGoalHit', () =>
        expect(ev('groupGoalHit', actor: '', payload: {'title': '50 workouts'}).line, '🎯 Group goal hit: 50 workouts'));
    test('birthday', () => expect(ev('birthday').line, "🎂 Today is Selin's birthday"));
  });

  group('SquadActivity.line — legacy aliases (name in payload.displayName, via fromMap)', () {
    test('streakLoss → streakBroken', () => expect(
        SquadActivity.fromMap('x', {'type': 'streakLoss', 'payload': {'displayName': 'Selin', 'length': 14}}).line,
        "Selin's 14-day streak ended"));
    test('pause → pauseStarted', () => expect(
        SquadActivity.fromMap('x', {'type': 'pause', 'payload': {'displayName': 'Selin', 'until': 'Sun'}}).line,
        'Selin paused until Sun'));
    test('return → pauseEnded', () => expect(
        SquadActivity.fromMap('x', {'type': 'return', 'payload': {'displayName': 'Selin'}}).line, 'Selin is back'));
  });

  test('emoji is defined for every type', () {
    for (final t in [
      'goalHit', 'streakMilestone', 'streakBroken', 'commentPosted', 'reactionSent',
      'pauseStarted', 'pauseEnded', 'memberJoined', 'memberLeft', 'intentionSet',
      'fullSquadDay', 'groupGoalHit', 'birthday',
    ]) {
      expect(ev(t).emoji, isNot('•'), reason: 'missing emoji for $t');
    }
  });
}
