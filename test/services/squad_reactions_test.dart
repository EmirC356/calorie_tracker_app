import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker_app/models/squad_reaction.dart';
import 'package:calorie_tracker_app/services/squad_service.dart';

void main() {
  group('SquadService reactions', () {
    late FakeFirebaseFirestore fake;
    late SquadService svc;
    const squadId = 's1';
    const date = '2026-06-09';

    setUp(() {
      fake = FakeFirebaseFirestore();
      svc = SquadService(firestore: fake);
    });

    test('addReaction writes a doc that watchReactions streams back', () async {
      await svc.addReaction(
          squadId: squadId, dateKey: date, fromUid: 'a', fromName: 'Alex',
          toUid: 'b', emoji: ReactionEmoji.fire);

      final list = await svc.watchReactions(squadId, date).first;
      expect(list.length, 1);
      expect(list.first.fromUid, 'a');
      expect(list.first.fromName, 'Alex');
      expect(list.first.toUid, 'b');
      expect(list.first.emoji, ReactionEmoji.fire);
    });

    test('removeReaction deletes only that reaction', () async {
      await svc.addReaction(
          squadId: squadId, dateKey: date, fromUid: 'a', fromName: 'Alex',
          toUid: 'b', emoji: ReactionEmoji.fire);
      await svc.addReaction(
          squadId: squadId, dateKey: date, fromUid: 'c', fromName: 'Sam',
          toUid: 'b', emoji: ReactionEmoji.clap);

      final before = await svc.watchReactions(squadId, date).first;
      final fire = before.firstWhere((r) => r.emoji == ReactionEmoji.fire);
      await svc.removeReaction(squadId: squadId, dateKey: date, reactionId: fire.id);

      final after = await svc.watchReactions(squadId, date).first;
      expect(after.length, 1);
      expect(after.first.emoji, ReactionEmoji.clap);
    });

    test('emoji glyphs map correctly', () {
      expect(ReactionEmoji.fire.glyph, '🔥');
      expect(ReactionEmoji.flex.glyph, '💪');
      expect(ReactionEmoji.clap.glyph, '👏');
    });
  });
}
