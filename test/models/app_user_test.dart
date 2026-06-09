import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('fromMap parses fields and a Timestamp createdAt', () {
      final ts = Timestamp.fromDate(DateTime(2026, 6, 9, 10));
      final u = AppUser.fromMap('u1', {
        'displayName': 'Emir',
        'photoURL': 'http://x/p.png',
        'fcmTokens': ['t1', 't2'],
        'createdAt': ts,
      });
      expect(u.uid, 'u1');
      expect(u.displayName, 'Emir');
      expect(u.photoURL, 'http://x/p.png');
      expect(u.fcmTokens, ['t1', 't2']);
      expect(u.createdAt, DateTime(2026, 6, 9, 10));
    });

    test('defaults displayName to Athlete when blank/missing', () {
      expect(AppUser.fromMap('u', {'displayName': ''}).displayName, 'Athlete');
      expect(AppUser.fromMap('u', {}).displayName, 'Athlete');
      expect(AppUser.fromMap('u', {}).fcmTokens, isEmpty);
    });

    test('toMap omits createdAt (written server-side) and keeps the rest', () {
      const u = AppUser(uid: 'u1', displayName: 'Emir', photoURL: 'p', fcmTokens: ['t']);
      final m = u.toMap();
      expect(m['displayName'], 'Emir');
      expect(m['photoURL'], 'p');
      expect(m['fcmTokens'], ['t']);
      expect(m.containsKey('createdAt'), isFalse);
    });

    test('copyWith updates only the given field', () {
      const u = AppUser(uid: 'u1', displayName: 'Old');
      expect(u.copyWith(displayName: 'New').displayName, 'New');
      expect(u.copyWith(displayName: 'New').uid, 'u1');
    });
  });
}
