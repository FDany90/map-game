import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/data/repositories/territory_repository.dart';
import 'package:map_spike/domain/models/build_result.dart';
import 'package:map_spike/domain/models/outpost.dart';

void main() {
  const pos = LatLng(-34.5889, -58.4306);
  const otherPos = LatLng(-34.60, -58.40);

  group('Campamento', () {
    test('colocar campamento descuenta el costo y lo ubica', () {
      final repo = TerritoryRepository(initialSupplies: 50, campCost: 20);
      expect(repo.camp, isNull);

      final r = repo.placeCamp(pos);

      expect(r, BuildResult.success);
      expect(repo.supplies, 30);
      expect(repo.camp, isNotNull);
      expect(repo.camp!.kind, OutpostKind.camp);
      expect(repo.camp!.position, pos);
    });

    test('sin suministros no se puede colocar (no toca el estado)', () {
      final repo = TerritoryRepository(initialSupplies: 10, campCost: 20);
      final r = repo.placeCamp(pos);
      expect(r, BuildResult.notEnoughSupplies);
      expect(repo.camp, isNull);
      expect(repo.supplies, 10);
    });

    test('volver a colocar lo MUEVE y vuelve a cobrar', () {
      final repo = TerritoryRepository(initialSupplies: 50, campCost: 20);
      repo.placeCamp(pos);
      final r = repo.placeCamp(otherPos);
      expect(r, BuildResult.success);
      expect(repo.camp!.position, otherPos);
      expect(repo.supplies, 10);
    });
  });

  group('Base permanente', () {
    test('fundar base descuenta el costo, se ancla al hex y queda permanente', () {
      final repo = TerritoryRepository(initialSupplies: 200, baseCost: 150);
      final r = repo.foundBase(playerPosition: pos, hexId: 42);
      expect(r, BuildResult.success);
      expect(repo.supplies, 50);
      expect(repo.hasBase, isTrue);
      expect(repo.base!.kind, OutpostKind.base);
      expect(repo.base!.position, pos);
      expect(repo.base!.hexId, 42);
    });

    test('sin suministros no se puede fundar', () {
      final repo = TerritoryRepository(initialSupplies: 100, baseCost: 150);
      final r = repo.foundBase(playerPosition: pos);
      expect(r, BuildResult.notEnoughSupplies);
      expect(repo.hasBase, isFalse);
    });

    test('no se puede fundar una segunda base (permanente)', () {
      final repo = TerritoryRepository(initialSupplies: 500, baseCost: 150);
      repo.foundBase(playerPosition: pos);
      final r = repo.foundBase(playerPosition: otherPos);
      expect(r, BuildResult.alreadyHasBase);
      // La base original no se movió.
      expect(repo.base!.position, pos);
    });
  });

  test('reset limpia campamento y base', () {
    final repo = TerritoryRepository(initialSupplies: 500);
    repo.placeCamp(pos);
    repo.foundBase(playerPosition: pos);
    repo.reset();
    expect(repo.camp, isNull);
    expect(repo.base, isNull);
    expect(repo.hasBase, isFalse);
  });
}
