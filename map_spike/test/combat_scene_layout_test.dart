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
  });
}
