import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_tracker_app/models/index.dart';
import 'package:calorie_tracker_app/providers/squad_provider.dart';
import 'package:calorie_tracker_app/services/auth_service.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';
import 'package:calorie_tracker_app/widgets/squad/member_card_compact.dart';
import 'package:calorie_tracker_app/widgets/squad/intentions_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpCard(WidgetTester tester, MemberCardCompact card) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
    await tester.pump();
  }

  group('MemberCardCompact', () {
    testWidgets('hit member → Hit pill + 3 reaction pills with count', (tester) async {
      await pumpCard(tester, MemberCardCompact(
        member: const SquadMember(
            uid: 'a', displayName: 'Ana',
            goal: SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2000)),
        entry: const SquadDayEntry(uid: 'a', status: GoalStatus.hit),
        isMe: false,
        reactionCounts: const {ReactionEmoji.fire: 2},
        onReact: (_) {},
        onTap: () {},
      ));
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Hit'), findsOneWidget);
      expect(find.text('🔥'), findsWidgets);
      expect(find.text('💪'), findsWidgets);
      expect(find.text('2'), findsOneWidget); // fire count
    });

    testWidgets('paused member → Paused pill', (tester) async {
      await pumpCard(tester, MemberCardCompact(
        member: const SquadMember(
            uid: 'a', displayName: 'Ana', pause: SquadPause(active: true),
            goal: SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2000)),
        entry: const SquadDayEntry(uid: 'a', status: GoalStatus.inProgress, paused: true),
        isMe: false,
        onReact: (_) {},
        onTap: () {},
      ));
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('own card disables reactions but still shows the glyphs', (tester) async {
      await pumpCard(tester, MemberCardCompact(
        member: const SquadMember(
            uid: 'me', displayName: 'Me',
            goal: SquadGoal(calorieMode: CalorieMode.cap, calorieTarget: 2000)),
        entry: const SquadDayEntry(uid: 'me', status: GoalStatus.missed),
        isMe: true,
        onReact: null, // own card
        onTap: () {},
      ));
      expect(find.text('Me (you)'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('👏'), findsWidgets); // pills render even when disabled
    });
  });

  group('IntentionsStrip', () {
    final week = isoWeekKey(DateTime.now());

    Future<void> pumpStrip(WidgetTester tester, FakeFirebaseFirestore fs) async {
      final service = SquadService(firestore: fs);
      final authService = AuthService(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
          googleSignIn: GoogleSignIn());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SquadProvider(service: service, authService: authService)),
        ],
        child: const MaterialApp(home: Scaffold(body: IntentionsStrip(squadId: 's1', myUid: 'me'))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
    }

    Future<void> seedMembers(FakeFirebaseFirestore fs, List<String> uids) async {
      await fs.doc('squads/s1').set({'name': 'S', 'ownerUid': 'me', 'memberUids': uids, 'inviteCode': '123456'});
      for (final u in uids) {
        await fs.doc('squads/s1/members/$u').set({'sharingLevel': 'status', 'displayName': u.toUpperCase()});
      }
    }

    testWidgets('hidden when no one has an intention', (tester) async {
      final fs = FakeFirebaseFirestore();
      await seedMembers(fs, ['me', 'a']);
      await pumpStrip(tester, fs);
      expect(find.text('THIS WEEK'), findsNothing);
    });

    testWidgets('partial — a squadmate set one, I get "Set yours"', (tester) async {
      final fs = FakeFirebaseFirestore();
      await seedMembers(fs, ['me', 'a']);
      await fs.doc('squads/s1/intentions/$week/members/a').set({'uid': 'a', 'text': 'Gym 3x'});
      await pumpStrip(tester, fs);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('Gym 3x'), findsOneWidget);
      expect(find.text('Set yours'), findsOneWidget);
    });

    testWidgets('all set — chips, no "Set yours"', (tester) async {
      final fs = FakeFirebaseFirestore();
      await seedMembers(fs, ['me', 'a']);
      await fs.doc('squads/s1/intentions/$week/members/me').set({'uid': 'me', 'text': 'Log meals'});
      await fs.doc('squads/s1/intentions/$week/members/a').set({'uid': 'a', 'text': 'Gym 3x'});
      await pumpStrip(tester, fs);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('Gym 3x'), findsOneWidget);
      expect(find.text('Log meals'), findsOneWidget);
      expect(find.text('Set yours'), findsNothing);
    });
  });
}
