import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/squad.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/snapshot_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/widgets/squad/squad_list_card.dart';
import 'package:calorie_tracker_app/widgets/ui/member_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final today = SnapshotService.dateKey(DateTime.now());

  Future<void> pumpCard(WidgetTester tester, FakeFirebaseFirestore fs,
      {required List<String> memberUids,
      Map<String, Map<String, dynamic>> members = const {},
      Map<String, Map<String, dynamic>> entries = const {}}) async {
    await fs.doc('squads/s1').set({
      'name': 'Gym Bros', 'ownerUid': 'me', 'memberUids': memberUids, 'inviteCode': '123456',
    });
    for (final e in members.entries) {
      await fs.doc('squads/s1/members/${e.key}').set(e.value);
    }
    for (final e in entries.entries) {
      await fs.doc('squads/s1/days/$today/entries/${e.key}').set(e.value);
    }

    final service = SquadService(firestore: fs);
    final authService = AuthService(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        googleSignIn: GoogleSignIn());
    final squad = Squad.fromMap('s1', {
      'name': 'Gym Bros', 'ownerUid': 'me', 'memberUids': memberUids, 'inviteCode': '123456',
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
      ],
      child: MaterialApp(home: Scaffold(body: SquadListCard(squad: squad, uid: 'me'))),
    ));
    await tester.pump(); // bind + first stream frame
    await tester.pump(const Duration(milliseconds: 150)); // stream emits
  }

  testWidgets('1 active member who hit', (tester) async {
    final fs = FakeFirebaseFirestore();
    await pumpCard(tester, fs,
        memberUids: ['me'],
        members: {'me': {'sharingLevel': 'status', 'displayName': 'Me'}},
        entries: {'me': {'status': 'hit'}});
    expect(find.text('Gym Bros'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget); // 1 of 1 hit
    expect(find.byType(MemberAvatar), findsOneWidget);
  });

  testWidgets('mixed statuses — hit count + avatars', (tester) async {
    final fs = FakeFirebaseFirestore();
    await pumpCard(tester, fs, memberUids: ['a', 'b', 'c'], members: {
      'a': {'sharingLevel': 'status', 'displayName': 'A'},
      'b': {'sharingLevel': 'status', 'displayName': 'B'},
      'c': {'sharingLevel': 'status', 'displayName': 'C'},
    }, entries: {
      'a': {'status': 'hit'}, 'b': {'status': 'inProgress'}, 'c': {'status': 'missed'},
    });
    expect(find.text('1/3'), findsOneWidget); // only A hit
    expect(find.byType(MemberAvatar), findsNWidgets(3));
  });

  testWidgets('all paused — 0 hits, avatars still shown', (tester) async {
    final fs = FakeFirebaseFirestore();
    await pumpCard(tester, fs, memberUids: ['a', 'b'], members: {
      'a': {'sharingLevel': 'status', 'displayName': 'A'},
      'b': {'sharingLevel': 'status', 'displayName': 'B'},
    }, entries: {
      'a': {'status': 'paused', 'paused': true},
      'b': {'status': 'paused', 'paused': true},
    });
    expect(find.text('0/2'), findsOneWidget);
    expect(find.byType(MemberAvatar), findsNWidgets(2));
  });

  testWidgets('empty squad (no member docs yet)', (tester) async {
    final fs = FakeFirebaseFirestore();
    await pumpCard(tester, fs, memberUids: ['me']);
    expect(find.text('Gym Bros'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget); // falls back to memberCount
  });
}
