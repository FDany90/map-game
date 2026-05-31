import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/domain/models/osm_feature.dart';
import 'package:map_spike/domain/models/osm_scene.dart';
import 'package:map_spike/domain/models/streets_source.dart';
import 'package:map_spike/domain/models/zone_profile.dart';

const _center = LatLng(-34.6, -58.4);
const _mPerDegLat = 111320.0;

/// Construye una calle recta de [meters] hacia el norte desde [start].
OsmFeature _street(String type, LatLng start, double meters) {
  final end = LatLng(start.latitude + meters / _mPerDegLat, start.longitude);
  return OsmFeature(
    id: 1,
    kind: OsmFeatureKind.street,
    tags: {'highway': type},
    geometry: [start, end],
  );
}

OsmFeature _area() => OsmFeature(
      id: 9,
      kind: OsmFeatureKind.leisure,
      tags: const {'leisure': 'park'},
      geometry: const [
        LatLng(-34.6, -58.4),
        LatLng(-34.6, -58.399),
        LatLng(-34.599, -58.399),
        LatLng(-34.6, -58.4),
      ],
    );

OsmScene _scene(List<OsmFeature> features, {double radius = 150}) => OsmScene(
      center: _center,
      radiusMeters: radius,
      features: features,
      source: StreetsSource.overpass,
    );

void main() {
  group('ZoneProfile.fromScene', () {
    test('trama de avenidas → denso urbano', () {
      // Varias avenidas: trama densa (muchas calles + avenidas).
      final streets = [
        for (var i = 0; i < 6; i++) _street('secondary', _center, 290),
        _street('primary', _center, 290),
      ];
      final p = ZoneProfile.fromScene(_scene(streets));
      expect(p.character, ZoneCharacter.denseUrban);
      expect(p.majorRoads, greaterThanOrEqualTo(1));
    });

    test('una avenida sola, sin nada alrededor → ruta / corredor (no denso)', () {
      // El bug que reportó Daniel: avenida con pasto al lado, sin casas.
      final p = ZoneProfile.fromScene(_scene([_street('primary', _center, 2000)]));
      expect(p.character, ZoneCharacter.roadCorridor);
      expect(p.hasBuildings, isFalse);
    });

    test('avenida larga NO infla la densidad (se recorta al radio)', () {
      // Una sola calle de 2 km cruzando un radio de 150 m: la longitud contada
      // debe ser ~el diámetro (≤ 2·radio), no los 2000 m enteros.
      final p = ZoneProfile.fromScene(_scene([_street('primary', _center, 2000)]));
      expect(p.streetLengthMeters, lessThanOrEqualTo(2 * 150 + 1));
    });

    test('muchos edificios → denso urbano aunque no haya avenida', () {
      final feats = <OsmFeature>[
        _street('residential', _center, 100),
        for (var i = 0; i < 9; i++)
          OsmFeature(
            id: 100 + i,
            kind: OsmFeatureKind.building,
            tags: const {'building': 'apartments'},
            geometry: const [
              LatLng(-34.6, -58.4),
              LatLng(-34.6, -58.3999),
              LatLng(-34.5999, -58.3999),
              LatLng(-34.6, -58.4),
            ],
          ),
      ];
      final p = ZoneProfile.fromScene(_scene(feats));
      expect(p.character, ZoneCharacter.denseUrban);
      expect(p.hasBuildings, isTrue);
    });

    test('calles residenciales → barrio de casas', () {
      final streets = [
        for (var i = 0; i < 4; i++) _street('residential', _center, 200),
      ];
      final p = ZoneProfile.fromScene(_scene(streets));
      expect(p.character, ZoneCharacter.residential);
    });

    test('senderos + parque, sin autos → parque / abierto', () {
      final feats = <OsmFeature>[
        _street('footway', _center, 120),
        _street('footway', _center, 120),
        _street('path', _center, 120),
        _area(),
      ];
      final p = ZoneProfile.fromScene(_scene(feats));
      expect(p.character, ZoneCharacter.openGreen);
      expect(p.hasGreen, isTrue);
    });

    test('muy poca calle y sin avenidas → rural', () {
      final p = ZoneProfile.fromScene(_scene([_street('unclassified', _center, 60)]));
      expect(p.character, ZoneCharacter.rural);
    });

    test('escena vacía → indeterminado', () {
      final p = ZoneProfile.fromScene(_scene(const []));
      expect(p.character, ZoneCharacter.unknown);
      expect(p.streetLengthMeters, 0);
    });

    test('es determinista: mismo input → mismo resultado', () {
      final streets = [
        for (var i = 0; i < 4; i++) _street('residential', _center, 200),
      ];
      final a = ZoneProfile.fromScene(_scene(streets));
      final b = ZoneProfile.fromScene(_scene(streets));
      expect(a.character, b.character);
      expect(a.streetDensity, b.streetDensity);
    });
  });
}
