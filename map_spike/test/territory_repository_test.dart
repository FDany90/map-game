// Tests de la economía, ahora aislada de la UI gracias a la nueva arquitectura.
import 'package:flutter_test/flutter_test.dart';
import 'package:map_spike/data/repositories/territory_repository.dart';
import 'package:map_spike/domain/models/claim_result.dart';

void main() {
  group('TerritoryRepository', () {
    test('arranca con los suministros iniciales y sin hexágonos', () {
      final repo = TerritoryRepository(initialSupplies: 50);
      expect(repo.supplies, 50);
      expect(repo.claimedCount, 0);
      expect(repo.productionPerSecond, 0);
    });

    test('reclamar descuenta el costo y marca el hexágono', () {
      final repo = TerritoryRepository(initialSupplies: 50, claimCost: 10);
      expect(repo.claim(1), ClaimResult.success);
      expect(repo.supplies, 40);
      expect(repo.claimedCount, 1);
      expect(repo.isClaimed(1), isTrue);
    });

    test('reclamar el mismo hexágono dos veces es no-op', () {
      final repo = TerritoryRepository(initialSupplies: 50, claimCost: 10);
      repo.claim(1);
      expect(repo.claim(1), ClaimResult.alreadyOwned);
      expect(repo.supplies, 40); // no volvió a descontar
      expect(repo.claimedCount, 1);
    });

    test('sin suministros suficientes no reclama ni descuenta', () {
      final repo = TerritoryRepository(initialSupplies: 5, claimCost: 10);
      expect(repo.claim(1), ClaimResult.notEnoughSupplies);
      expect(repo.supplies, 5);
      expect(repo.claimedCount, 0);
    });

    test('produce acumula según hexágonos reclamados y dt', () {
      final repo = TerritoryRepository(
        initialSupplies: 50,
        claimCost: 10,
        yieldPerHexPerSecond: 0.5,
      );
      repo.claim(1); // supplies = 40, producción = 0.5/seg
      repo.produce(2); // +1.0
      expect(repo.supplies, closeTo(41, 1e-9));
    });

    test('produce sin hexágonos no cambia nada', () {
      final repo = TerritoryRepository(initialSupplies: 50);
      repo.produce(10);
      expect(repo.supplies, 50);
    });

    test('reset vuelve al estado inicial', () {
      final repo = TerritoryRepository(initialSupplies: 50, claimCost: 10);
      repo.claim(1);
      repo.claim(2);
      repo.reset();
      expect(repo.supplies, 50);
      expect(repo.claimedCount, 0);
      expect(repo.isClaimed(1), isFalse);
    });
  });
}
