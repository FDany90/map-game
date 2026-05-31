import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Categoría de un elemento OSM, derivada de sus tags. Es la primera
/// clasificación con la que el generador de escenas (ADR 0007) decide qué
/// pieza dibujar. Ver `docs/14-osm-datos-referencia.md`.
enum OsmFeatureKind { street, building, leisure, other }

/// Un elemento OSM (`way`) con su **geometría completa** y **todos sus tags**.
///
/// A diferencia del pipeline de calles (que descarta los tags y guarda solo
/// polylines), acá se preservan los tags porque **son los parámetros de
/// generación** de la escena isométrica: tipo de calle, pisos, altura, uso, etc.
class OsmFeature {
  OsmFeature({
    required this.id,
    required this.kind,
    required this.tags,
    required this.geometry,
  });

  final int id;
  final OsmFeatureKind kind;
  final Map<String, String> tags;
  final List<LatLng> geometry;

  /// Clasifica el way según sus tags (prioridad: edificio > calle > leisure).
  static OsmFeatureKind kindFromTags(Map<String, String> tags) {
    if (tags.containsKey('building')) return OsmFeatureKind.building;
    if (tags.containsKey('highway')) return OsmFeatureKind.street;
    if (tags.containsKey('leisure')) return OsmFeatureKind.leisure;
    return OsmFeatureKind.other;
  }

  /// `true` si la geometría es un polígono cerrado (footprint de edificio/área).
  bool get isClosed =>
      geometry.length >= 4 && geometry.first == geometry.last;

  /// Rumbo (bearing) en grados \[0,360) del primer al último punto, donde
  /// 0 = Norte y 90 = Este. La dirección **no es un tag**: se calcula de la
  /// geometría. Es la base del "norte real" del ADR 0007.
  double get bearingDeg {
    if (geometry.length < 2) return 0;
    final a = geometry.first;
    final b = geometry.last;
    final midLatRad = ((a.latitude + b.latitude) / 2) * math.pi / 180;
    final dEast = (b.longitude - a.longitude) * math.cos(midLatRad);
    final dNorth = b.latitude - a.latitude;
    return (math.atan2(dEast, dNorth) * 180 / math.pi + 360) % 360;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'tags': tags,
        'geom': [
          for (final p in geometry) [p.latitude, p.longitude],
        ],
      };

  static OsmFeature fromJson(Map<String, dynamic> json) => OsmFeature(
        id: (json['id'] as num?)?.toInt() ?? 0,
        kind: OsmFeatureKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => OsmFeatureKind.other,
        ),
        tags: {
          for (final e in (json['tags'] as Map? ?? const {}).entries)
            e.key.toString(): e.value.toString(),
        },
        geometry: [
          for (final p in (json['geom'] as List? ?? const []))
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
      );
}
