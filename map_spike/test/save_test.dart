import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/data/repositories/territory_repository.dart';
import 'package:map_spike/domain/models/outpost.dart';
import 'package:map_spike/domain/models/player_save.dart';

void main() {
  group('PlayerSave (serialización)', () {
    test('roundtrip por string: el estado sobrevive a JSON ↔ objeto', () {
      final repo = TerritoryRepository(initialSupplies: 500);
      repo.claim(1);
      repo.claim(2);
      repo.placeCamp(const LatLng(-34.60, -58.40));
      repo.foundBase(playerPosition: const LatLng(-34.5889, -58.4306), hexId: 7);
      repo.movePlayerTo(const LatLng(-34.59, -58.43));

      // Save → string → objeto (el camino real del SaveStore).
      final jsonStr = jsonEncode(repo.toSave().toJson());
      final restored =
          PlayerSave.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored, isNotNull);

      final repo2 = TerritoryRepository();
      repo2.restore(restored!);

      expect(repo2.supplies, repo.supplies);
      expect(repo2.claimedCount, 2);
      expect(repo2.isClaimed(1), isTrue);
      expect(repo2.isClaimed(2), isTrue);
      expect(repo2.camp!.kind, OutpostKind.camp);
      expect(repo2.camp!.position, const LatLng(-34.60, -58.40));
      expect(repo2.base!.hexId, 7);
      expect(repo2.playerPosition, const LatLng(-34.59, -58.43));
    });

    test('save sin camp/base se restaura con nulls', () {
      final repo = TerritoryRepository();
      final restored = PlayerSave.fromJson(
          jsonDecode(jsonEncode(repo.toSave().toJson())) as Map<String, dynamic>);
      final repo2 = TerritoryRepository()..restore(restored!);
      expect(repo2.camp, isNull);
      expect(repo2.base, isNull);
    });

    test('versión incompatible → null (no rompe, arranca de cero)', () {
      expect(PlayerSave.fromJson({'version': 999}), isNull);
    });

    test('JSON corrupto / incompleto → null', () {
      expect(PlayerSave.fromJson({'garbage': true}), isNull);
      expect(PlayerSave.fromJson({'version': 1, 'supplies': 'no-num'}), isNull);
    });
  });

  group('Catch-up offline acotado', () {
    TerritoryRepository repoConHex() {
      final repo = TerritoryRepository(initialSupplies: 10); // 1 claim = -10 → 0
      repo.claim(1);
      expect(repo.supplies, 0);
      return repo;
    }

    test('elapsed corto produce proporcional (no capea)', () {
      final repo = repoConHex();
      final now = DateTime.fromMillisecondsSinceEpoch(10000000000);
      final lastSeen =
          now.millisecondsSinceEpoch - const Duration(minutes: 10).inMilliseconds;
      repo.applyOfflineCatchUp(lastSeen, now: now);
      // 1 hex × 0.5/s × 600 s = 300.
      expect(repo.supplies, 300);
    });

    test('elapsed largo se CAPEA al tope (1 h)', () {
      final repo = repoConHex();
      final now = DateTime.fromMillisecondsSinceEpoch(10000000000);
      final lastSeen =
          now.millisecondsSinceEpoch - const Duration(hours: 5).inMilliseconds;
      repo.applyOfflineCatchUp(lastSeen, now: now);
      // Capeado a 3600 s: 1 hex × 0.5 × 3600 = 1800 (no 9000).
      expect(repo.supplies, 1800);
    });

    test('lastSeen futuro / elapsed negativo → no produce', () {
      final repo = repoConHex();
      final now = DateTime.fromMillisecondsSinceEpoch(10000000000);
      repo.applyOfflineCatchUp(
          now.millisecondsSinceEpoch + 1000, now: now);
      expect(repo.supplies, 0);
    });
  });
}
