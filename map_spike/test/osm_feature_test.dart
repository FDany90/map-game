import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_spike/domain/models/osm_feature.dart';

void main() {
  group('OsmFeature.kindFromTags', () {
    test('building tiene prioridad sobre highway', () {
      expect(
        OsmFeature.kindFromTags({'building': 'yes', 'highway': 'service'}),
        OsmFeatureKind.building,
      );
    });

    test('highway → street', () {
      expect(OsmFeature.kindFromTags({'highway': 'residential'}),
          OsmFeatureKind.street);
    });

    test('leisure → leisure', () {
      expect(OsmFeature.kindFromTags({'leisure': 'park'}),
          OsmFeatureKind.leisure);
    });

    test('sin tags conocidos → other', () {
      expect(OsmFeature.kindFromTags({'foo': 'bar'}), OsmFeatureKind.other);
    });
  });

  group('OsmFeature.bearingDeg', () {
    OsmFeature street(List<LatLng> geom) => OsmFeature(
          id: 1,
          kind: OsmFeatureKind.street,
          tags: const {'highway': 'residential'},
          geometry: geom,
        );

    test('hacia el norte ≈ 0°', () {
      final b = street([const LatLng(0, 0), const LatLng(0.001, 0)]).bearingDeg;
      expect(b, closeTo(0, 1));
    });

    test('hacia el este ≈ 90°', () {
      final b = street([const LatLng(0, 0), const LatLng(0, 0.001)]).bearingDeg;
      expect(b, closeTo(90, 1));
    });

    test('hacia el sur ≈ 180°', () {
      final b = street([const LatLng(0, 0), const LatLng(-0.001, 0)]).bearingDeg;
      expect(b, closeTo(180, 1));
    });
  });

  group('OsmFeature isClosed / JSON', () {
    test('polígono cerrado se detecta', () {
      final f = OsmFeature(
        id: 2,
        kind: OsmFeatureKind.building,
        tags: const {'building': 'yes'},
        geometry: const [
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 1),
          LatLng(0, 0),
        ],
      );
      expect(f.isClosed, isTrue);
    });

    test('roundtrip toJson/fromJson preserva tags y geometría', () {
      final original = OsmFeature(
        id: 42,
        kind: OsmFeatureKind.building,
        tags: const {'building': 'retail', 'building:levels': '2'},
        geometry: const [LatLng(-34.6, -58.4), LatLng(-34.61, -58.41)],
      );
      final back = OsmFeature.fromJson(original.toJson());
      expect(back.id, 42);
      expect(back.kind, OsmFeatureKind.building);
      expect(back.tags['building:levels'], '2');
      expect(back.geometry.length, 2);
      expect(back.geometry.first.latitude, closeTo(-34.6, 1e-9));
    });
  });
}
