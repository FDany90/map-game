import 'package:flutter_test/flutter_test.dart';
import 'package:map_spike/domain/models/scene_template.dart';

void main() {
  group('SceneTemplates — biblioteca', () {
    test('hay templates y todos tienen id, calle y slots', () {
      expect(SceneTemplates.all, isNotEmpty);
      for (final t in SceneTemplates.all) {
        expect(t.id, isNotEmpty);
        expect(t.slots, isNotEmpty);
        // Toda escena tiene la calzada principal y veredas.
        expect(t.countOf(SlotKind.street), greaterThanOrEqualTo(1),
            reason: '${t.id} sin calle');
        expect(t.countOf(SlotKind.sidewalk), greaterThanOrEqualTo(1),
            reason: '${t.id} sin vereda');
      }
    });

    test('ids únicos', () {
      final ids = SceneTemplates.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('toda escena tiene spawn de jugador y de enemigo', () {
      for (final t in SceneTemplates.all) {
        expect(t.countOf(SlotKind.spawnPlayer), 1, reason: t.id);
        expect(t.countOf(SlotKind.spawnEnemy), 1, reason: t.id);
      }
    });

    test('los slots caen en street-space válido (u∈[-1,1] del eje, v a lo largo)', () {
      // v se normaliza a lo largo de la calle; una cuadra (residential.block) llega
      // a la esquina del fondo (~1.3) y arranca antes del 0 (~-0.25).
      for (final t in SceneTemplates.all) {
        for (final s in t.slots) {
          expect(s.v, inInclusiveRange(-0.4, 1.4), reason: '${t.id} v=${s.v}');
          expect(s.u, inInclusiveRange(-1.2, 1.2), reason: '${t.id} u=${s.u}');
          expect(s.levels, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('templates concretos', () {
    test('corner tiene un landmark de esquina', () {
      final t = SceneTemplates.residentialCorner();
      expect(t.topology, Topology.corner);
      expect(t.countOf(SlotKind.cornerLandmark), greaterThanOrEqualTo(1));
      expect(t.countOf(SlotKind.crossing), greaterThanOrEqualTo(1));
    });

    test('intersection es zona densa con edificios altos', () {
      final t = SceneTemplates.denseUrbanIntersection();
      expect(t.zone, TemplateZone.denseUrban);
      final maxLevels = t.slots
          .where((s) => s.kind == SlotKind.buildingRow)
          .map((s) => s.levels)
          .fold<double>(0, (a, b) => a > b ? a : b);
      expect(maxLevels, greaterThanOrEqualTo(6));
    });

    test('generación de edificios es determinista (misma escena siempre igual)', () {
      final a = SceneTemplates.residentialMidBlock();
      final b = SceneTemplates.residentialMidBlock();
      expect(a.countOf(SlotKind.buildingRow), b.countOf(SlotKind.buildingRow));
      for (var i = 0; i < a.slots.length; i++) {
        expect(a.slots[i].u, b.slots[i].u);
        expect(a.slots[i].v, b.slots[i].v);
        expect(a.slots[i].levels, b.slots[i].levels);
      }
    });
  });

  test('SlotKind.isFlat clasifica bien planos vs con altura', () {
    expect(SlotKind.street.isFlat, isTrue);
    expect(SlotKind.sidewalk.isFlat, isTrue);
    expect(SlotKind.spawnPlayer.isFlat, isTrue);
    expect(SlotKind.buildingRow.isFlat, isFalse);
    expect(SlotKind.cornerLandmark.isFlat, isFalse);
    expect(SlotKind.prop.isFlat, isFalse);
  });
}
