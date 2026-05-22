import 'package:flutter_test/flutter_test.dart';
import 'package:sticker_swap/utils/generator.dart';

void main() {
  group('StickerGenerator Seeding Tests', () {
    test('Should generate exactly 32 World Cup groups-divided squads', () {
      final teams = StickerGenerator.generateTeams();
      expect(teams.length, equals(32));
      
      // Verify group representation A-H
      final groups = teams.map((t) => t.group).toSet();
      expect(groups, containsAll(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']));
    });

    test('Should generate exactly 576 parody players (18 players per squad)', () {
      final teams = StickerGenerator.generateTeams();
      final players = StickerGenerator.generatePlayers(teams);
      expect(players.length, equals(576));

      // Each team should have exactly 18 players
      for (var team in teams) {
        final roster = players.where((p) => p.teamId == team.id).toList();
        expect(roster.length, equals(18));

        // Roster should have numbers 1 to 18
        final numbers = roster.map((p) => p.number).toList()..sort();
        expect(numbers, equals(List.generate(18, (i) => i + 1)));
      }
    });

    test('Should successfully apply superstar overrides with high ratings and styles', () {
      final teams = StickerGenerator.generateTeams();
      final players = StickerGenerator.generatePlayers(teams);

      // Verify Leonel Mesi is on Argentina (Team 9) with high rating
      final mesi = players.firstWhere((p) => p.name == 'Leonel Mesi');
      expect(mesi.teamId, equals(9));
      expect(mesi.number, equals(10));
      expect(mesi.rating, equals(99));
      expect(mesi.isShiny, isTrue);

      // Verify Crisalno Ronalzo is on Portugal (Team 29) with high rating
      final ronaldo = players.firstWhere((p) => p.name == 'Crisalno Ronalzo');
      expect(ronaldo.teamId, equals(29));
      expect(ronaldo.number, equals(7));
      expect(ronaldo.rating, equals(98));
      expect(ronaldo.isShiny, isTrue);

      // Verify Erling Haalan is on Norway (Team 24) with high rating
      final haalan = players.firstWhere((p) => p.name == 'Erling Haalan');
      expect(haalan.teamId, equals(24));
      expect(haalan.number, equals(9));
      expect(haalan.rating, equals(96));
      expect(haalan.isShiny, isTrue);
    });

    test('Should programmaticly output valid SQL seeding insert queries', () {
      final sqlSeed = StickerGenerator.generateSQLSeed();
      expect(sqlSeed, contains('-- STICKER SWAP - SEED DATA FOR TEAMS & PLAYERS'));
      expect(sqlSeed, contains('INSERT INTO public.teams'));
      expect(sqlSeed, contains('INSERT INTO public.players'));
      expect(sqlSeed, contains('Leonel Mesi'));
      expect(sqlSeed, contains('Crisalno Ronalzo'));
    });
  });
}
