import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/domain/models/combat_scene_layout.dart';
import 'package:map_spike/domain/models/osm_feature.dart';
import 'package:map_spike/domain/models/osm_scene.dart';
import 'package:map_spike/domain/models/streets_source.dart';

const _center = LatLng(-34.6, -58.4);
const _mPerDegLat = 111320.0;

/// Calle recta con un [bearingDeg] (grados desde el norte, horario) y [meters].
OsmFeature _street(String type, double bearingDeg, double meters) {
  final mPerDegLon = _mPerDegLat * math.cos(_center.latitude * math.pi / 180);
  final rad = bearingDeg * math.pi / 180;
  final end = LatLng(
    _center.latitude + (math.cos(rad) * meters) / _mPerDegLat,
    _center.longitude + (math.sin(rad) * meters) / mPerDegLon,
  );
  return OsmFeature(
    id: 1,
    kind: OsmFeatureKind.street,
    tags: {'highway': type},
    geometry: [_center, end],
  );
}

/// Un edificio real cuadrado a ~[offsetMeters] del centro (a media cuadra, como
/// vienen en OSM), con pisos declarados.
OsmFeature _building(int i, {double offsetMeters = 80, int levels = 10}) {
  final mPerDegLon = _mPerDegLat * math.cos(_center.latitude * math.pi / 180);
  final off = offsetMeters + i * 2;
  LatLng p(double dx, double dy) => LatLng(
        _center.latitude + dy / _mPerDegLat,
        _center.longitude + dx / mPerDegLon,
      );
  return OsmFeature(
    id: 100 + i,
    kind: OsmFeatureKind.building,
    tags: {'building': 'yes', 'building:levels': '$levels'},
    geometry: [
      p(off, off),
      p(off + 8, off),
      p(off + 8, off + 8),
      p(off, off + 8),
      p(off, off),
    ],
  );
}

OsmScene _scene(List<OsmFeature> features) => OsmScene(
      center: _center,
      radiusMeters: 150,
      features: features,
      source: StreetsSource.overpass,
    );

/// Qué tan "horizontal" quedó la calle principal: 0 = vertical, 1 = horizontal.
double _horizontalness(CombatSceneLayout l) {
  final main = l.streets.firstWhere((s) => s.isMain);
  final a = main.points.first, b = main.points.last;
  final dx = (b.x - a.x).abs(), dy = (b.y - a.y).abs();
  final len = math.sqrt(dx * dx + dy * dy);
  return len == 0 ? 0 : dx / len;
}

void main() {
  group('CombatSceneLayout.fromScene', () {
    // La calle SIEMPRE se dibuja vertical (ADR 0007 rev). Estos tests verifican
    // que, venga como venga en OSM (horizontal, diagonal…), termina vertical.
    test('una calle E-O en OSM termina dibujada vertical', () {
      final l = CombatSceneLayout.fromScene(_scene([_street('residential', 90, 200)]));
      expect(_horizontalness(l), lessThan(0.02));
    });

    test('una calle a 45° en OSM tambien termina dibujada vertical', () {
      final l = CombatSceneLayout.fromScene(_scene([_street('residential', 45, 200)]));
      expect(_horizontalness(l), lessThan(0.02));
    });

    test('elige la avenida como principal sobre la residencial', () {
      final l = CombatSceneLayout.fromScene(_scene([
        _street('residential', 10, 100),
        _street('primary', 80, 300),
      ]));
      expect(l.streets.firstWhere((s) => s.isMain).type, 'primary');
    });

    test('el norte real se preserva como angulo (= rotacion aplicada)', () {
      final l = CombatSceneLayout.fromScene(_scene([_street('residential', 90, 200)]));
      expect(l.realNorthAngleRad.abs(), closeTo(math.pi / 2, 0.02));
    });

    // Regresión (bug 2026-05-31): una calle casi N-S guardada en OSM de norte→sur
    // (orden de nodos arbitrario) hacía rot≈π → daba toda la escena vuelta y el
    // norte apuntando hacia abajo. Ahora rot se normaliza a (−π/2, π/2]: la calle
    // queda vertical igual pero el norte NUNCA se invierte (rot pequeño).
    test('calle N-S guardada al reves no invierte el norte', () {
      final mPerDegLon = _mPerDegLat * math.cos(_center.latitude * math.pi / 180);
      LatLng p(double east, double north) => LatLng(
            _center.latitude + north / _mPerDegLat,
            _center.longitude + east / mPerDegLon,
          );
      // Nodos de norte a sur (al revés): antes esto disparaba la inversión.
      final reversed = OsmFeature(
        id: 1,
        kind: OsmFeatureKind.street,
        tags: const {'highway': 'residential'},
        geometry: [p(0, 150), p(0, -150)],
      );
      final l = CombatSceneLayout.fromScene(_scene([reversed]));
      // Norte casi arriba: |rot| chico, jamás ~π.
      expect(l.realNorthAngleRad.abs(), lessThan(0.02));
    });

    // La normalización nunca debe rotar más de 90°: el norte se mantiene a ±90°
    // de "arriba" venga como venga la calle en OSM.
    test('la rotacion aplicada nunca supera 90 grados', () {
      for (final bearing in [0.0, 30.0, 91.0, 135.0, 200.0, 270.0, 350.0]) {
        final l =
            CombatSceneLayout.fromScene(_scene([_street('residential', bearing, 200)]));
        expect(l.realNorthAngleRad.abs(), lessThanOrEqualTo(math.pi / 2 + 1e-9),
            reason: 'bearing $bearing → rot ${l.realNorthAngleRad}');
      }
    });

    test('zona residencial sin edificios OSM genera casas inferidas', () {
      final l = CombatSceneLayout.fromScene(_scene([
        for (var i = 0; i < 4; i++) _street('residential', 0, 180),
      ]));
      expect(l.buildings, isNotEmpty);
      expect(l.buildings.every((b) => b.inferred), isTrue);
    });

    // Regresión: denso urbano con edificios reales (a media cuadra) salía VACÍO
    // porque se salteaba la inferencia y los reales caían fuera de cuadro.
    // Ahora las paredes son siempre generadas; los reales son solo señal.
    test('denso urbano con edificios reales igual genera paredes (no vacío)',
        () {
      final l = CombatSceneLayout.fromScene(_scene([
        for (var i = 0; i < 4; i++) _street('primary', 0, 200),
        for (var i = 0; i < 12; i++) _building(i),
      ]));
      expect(l.realBuildingCount, 12);
      expect(l.buildings, isNotEmpty);
      expect(l.buildings.every((b) => b.inferred), isTrue);
    });

    test('es determinista: mismo punto, mismo nro de edificios inferidos', () {
      final s = _scene([for (var i = 0; i < 4; i++) _street('residential', 0, 180)]);
      final a = CombatSceneLayout.fromScene(s);
      final b = CombatSceneLayout.fromScene(s);
      expect(a.buildings.length, b.buildings.length);
    });

    test('parque/vacio no genera edificios', () {
      final l = CombatSceneLayout.fromScene(_scene(const []));
      expect(l.buildings, isEmpty);
    });

    // Regresión (bug 2026-05-31): si el jugador tocaba al costado de la calle, la
    // calle se dibujaba en su x real pero los edificios se generaban centrados en
    // el click → quedaban desalineados. Ahora la escena se re-centra: la calle
    // principal pasa por x≈0 y los edificios quedan pegados a ella.
    test('calle desplazada del click se re-centra en x=0', () {
      // Calle N-S corrida 40 m al este del punto tocado.
      final mPerDegLon = _mPerDegLat * math.cos(_center.latitude * math.pi / 180);
      LatLng p(double east, double north) => LatLng(
            _center.latitude + north / _mPerDegLat,
            _center.longitude + east / mPerDegLon,
          );
      final offsetStreet = OsmFeature(
        id: 1,
        kind: OsmFeatureKind.street,
        tags: const {'highway': 'residential'},
        geometry: [p(40, -150), p(40, 150)],
      );
      final l = CombatSceneLayout.fromScene(_scene([offsetStreet]));

      // La calle principal debe pasar cerca de x=0 (re-centrada).
      final main = l.streets.firstWhere((s) => s.isMain);
      final mainX =
          main.points.map((e) => e.x).reduce((a, b) => a + b) / main.points.length;
      expect(mainX.abs(), lessThan(1.0));

      // Y los edificios deben quedar pegados a la calle (a pocos metros de x=0),
      // no flotando a 40 m como antes del arreglo.
      expect(l.buildings, isNotEmpty);
      for (final b in l.buildings) {
        final nearEdge = b.footprint
            .map((e) => e.x.abs())
            .reduce((a, c) => a < c ? a : c);
        expect(nearEdge, lessThan(15),
            reason: 'edificio demasiado lejos de la calle: $nearEdge m');
      }
    });

    // Regresión (bug 2026-05-31): la rotación usaba la cuerda extremo-a-extremo,
    // así que una calle con un quiebre quedaba inclinada frente al jugador.
    // Ahora se usa la dirección del tramo más cercano al origen → el pedazo de
    // calle donde está parado el jugador queda vertical.
    test('calle con quiebre: el tramo del jugador queda vertical', () {
      final mPerDegLon = _mPerDegLat * math.cos(_center.latitude * math.pi / 180);
      LatLng p(double east, double north) => LatLng(
            _center.latitude + north / _mPerDegLat,
            _center.longitude + east / mPerDegLon,
          );
      // Tramo cercano N-S (vertical); luego quiebra en diagonal lejos → la cuerda
      // extremo-a-extremo es diagonal, pero el tramo del jugador es vertical.
      final bent = OsmFeature(
        id: 1,
        kind: OsmFeatureKind.street,
        tags: const {'highway': 'residential'},
        geometry: [p(0, -80), p(0, 0), p(120, 80)],
      );
      final l = CombatSceneLayout.fromScene(_scene([bent]));
      // El segmento de la calle principal más cercano al origen debe ser vertical.
      final main = l.streets.firstWhere((s) => s.isMain);
      var bestD2 = double.infinity;
      var nearHoriz = 1.0;
      for (var i = 0; i < main.points.length - 1; i++) {
        final a = main.points[i], b = main.points[i + 1];
        final mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
        final d2 = mx * mx + my * my;
        if (d2 < bestD2) {
          bestD2 = d2;
          final dx = (b.x - a.x).abs(), dy = (b.y - a.y).abs();
          final len = math.sqrt(dx * dx + dy * dy);
          nearHoriz = len == 0 ? 1.0 : dx / len;
        }
      }
      expect(nearHoriz, lessThan(0.05));
    });

    // Ningún edificio inferido debe montarse sobre la calle principal (x≈0).
    test('los edificios no pisan la calle principal', () {
      final l = CombatSceneLayout.fromScene(_scene([
        for (var i = 0; i < 4; i++) _street('primary', 0, 220),
      ]));
      final mainHalf =
          l.streets.firstWhere((s) => s.isMain).width / 2;
      for (final b in l.buildings) {
        // El footprint no debe cruzar la franja de la calzada principal.
        final minX = b.footprint.map((e) => e.x).reduce(math.min);
        final maxX = b.footprint.map((e) => e.x).reduce(math.max);
        final crossesAxis = minX < mainHalf && maxX > -mainHalf;
        expect(crossesAxis, isFalse,
            reason: 'edificio sobre la calle principal: [$minX, $maxX]');
      }
    });
  });
}
