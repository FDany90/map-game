import 'package:latlong2/latlong.dart';

import 'osm_feature.dart';
import 'streets_source.dart';

/// Conjunto de elementos OSM alrededor de un punto: la "materia prima" de una
/// escena isométrica (ADR 0007). Agrupa los features por categoría y conoce su
/// origen (Overpass / caché).
class OsmScene {
  OsmScene({
    required this.center,
    required this.radiusMeters,
    required this.features,
    required this.source,
  });

  final LatLng center;
  final double radiusMeters;
  final List<OsmFeature> features;
  final StreetsSource source;

  List<OsmFeature> get streets =>
      features.where((f) => f.kind == OsmFeatureKind.street).toList();

  List<OsmFeature> get buildings =>
      features.where((f) => f.kind == OsmFeatureKind.building).toList();

  List<OsmFeature> get areas =>
      features.where((f) => f.kind == OsmFeatureKind.leisure).toList();

  bool get isEmpty => features.isEmpty;
}
