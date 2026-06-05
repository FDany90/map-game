import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/data/services/threat_service.dart';
import 'package:map_spike/domain/models/map_marker.dart';

void main() {
  const spawn = LatLng(-34.5889, -58.4306); // Palermo (AppConfig.initialCenter)
  final service = ThreatService(spawn: spawn);

  group('ThreatService', () {
    test('es determinista: mismo centro → mismas amenazas', () {
      final a = service.threatsAround(spawn);
      final b = service.threatsAround(spawn);
      expect(a.length, b.length);
      expect(a, isNotEmpty);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id);
        expect(a[i].difficulty, b[i].difficulty);
        expect(a[i].position.latitude, b[i].position.latitude);
        expect(a[i].position.longitude, b[i].position.longitude);
      }
    });

    test('ids únicos y amenazas válidas', () {
      final t = service.threatsAround(spawn);
      final ids = t.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final m in t) {
        expect(m.kind, MarkerKind.zombieGroup);
        expect(m.difficulty, inInclusiveRange(1, 5));
        expect(m.enemies, isNotEmpty);
        expect(m.totalEnemies, greaterThan(0));
      }
    });

    test('gradiente: cerca del spawn hay fácil; lejos es difícil', () {
      // Cerca del spawn aparece al menos una amenaza de dificultad baja.
      final near = service.threatsAround(spawn);
      final minNear = near.map((m) => m.difficulty).reduce((a, b) => a < b ? a : b);
      expect(minNear, lessThanOrEqualTo(2));

      // Un centro a ~3 km del spawn: todas las amenazas son difíciles.
      final far = service.threatsAround(LatLng(spawn.latitude + 0.03, spawn.longitude));
      expect(far, isNotEmpty);
      for (final m in far) {
        expect(m.difficulty, greaterThanOrEqualTo(4), reason: m.id);
      }
    });

    test('composición escala con la dificultad (más difícil = más tipos)', () {
      final far = service.threatsAround(LatLng(spawn.latitude + 0.03, spawn.longitude));
      // A dificultad ≥3 aparece el Corredor.
      final hard = far.firstWhere((m) => m.difficulty >= 3);
      expect(hard.enemies.any((g) => g.type == EnemyType.corredor), isTrue);
    });
  });
}
