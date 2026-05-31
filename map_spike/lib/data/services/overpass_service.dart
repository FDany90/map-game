import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/osm_feature.dart';

/// Error al consultar Overpass (todos los endpoints fallaron).
class OverpassException implements Exception {
  OverpassException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'OverpassException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Cliente de **Overpass** (OSM): trae la geometría de las calles alrededor de
/// un punto. Servicio sin estado y "puro": solo habla con la API (prueba el
/// endpoint principal y un mirror) y **lanza** si todos fallan. La caché y el
/// fallback son responsabilidad del repositorio (`StreetsRepository`), no del
/// servicio. Ver `docs/11-zombies-calles-cost.md`.
class OverpassService {
  OverpassService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Endpoint principal + mirror de respaldo (verificados funcionando).
  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Overpass devuelve **406 Not Acceptable** sin un User-Agent propio
  /// (política OSM: identificá tu app).
  static const String _userAgent =
      'map-game-spike/0.1 (https://github.com/FDany90/map-game)';

  /// Trae las calles (`highway`) dentro de [radiusMeters] de [center].
  /// Lanza [OverpassException] si todos los endpoints fallan.
  Future<List<List<LatLng>>> fetchStreetsAround(
    LatLng center, {
    double radiusMeters = 300,
  }) async {
    final query = '[out:json][timeout:25];'
        'way["highway"](around:$radiusMeters,${center.latitude},${center.longitude});'
        'out geom;';
    final encoded = Uri.encodeQueryComponent(query);

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final resp = await _dio.get<Map<String, dynamic>>(
          '$endpoint?data=$encoded',
          options: Options(
            responseType: ResponseType.json,
            headers: const {'User-Agent': _userAgent},
            sendTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );
        final streets = _parseStreets(resp.data);
        if (streets.isNotEmpty) return streets;
        lastError = 'respuesta vacía';
      } catch (e) {
        lastError = e;
        debugPrint('OverpassService: falló $endpoint → $e');
      }
    }
    throw OverpassException('no se pudieron obtener calles', lastError);
  }

  /// Trae la **escena cruda** (calles + edificios + áreas/leisure) con sus
  /// **tags y geometría** dentro de [radiusMeters] de [center]. A diferencia de
  /// [fetchStreetsAround], conserva los tags (son los parámetros de generación
  /// de la escena isométrica; ver ADR 0007 / `docs/14-osm-datos-referencia.md`).
  /// Lanza [OverpassException] si todos los endpoints fallan.
  Future<List<OsmFeature>> fetchSceneAround(
    LatLng center, {
    double radiusMeters = 150,
  }) async {
    final c = '${center.latitude},${center.longitude}';
    final query = '[out:json][timeout:25];'
        '(way["highway"](around:$radiusMeters,$c);'
        'way["building"](around:$radiusMeters,$c);'
        'way["leisure"](around:$radiusMeters,$c););'
        'out geom;';
    final encoded = Uri.encodeQueryComponent(query);

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final resp = await _dio.get<Map<String, dynamic>>(
          '$endpoint?data=$encoded',
          options: Options(
            responseType: ResponseType.json,
            headers: const {'User-Agent': _userAgent},
            sendTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );
        final features = _parseFeatures(resp.data);
        if (features.isNotEmpty) return features;
        lastError = 'respuesta vacía';
      } catch (e) {
        lastError = e;
        debugPrint('OverpassService.fetchScene: falló $endpoint → $e');
      }
    }
    throw OverpassException('no se pudo obtener la escena', lastError);
  }

  /// Parsea la respuesta de Overpass (`out geom`) preservando tags + geometría.
  List<OsmFeature> _parseFeatures(Map<String, dynamic>? data) {
    final elements = (data?['elements'] as List?) ?? const [];
    final out = <OsmFeature>[];
    for (final e in elements) {
      if (e is! Map) continue;
      final geom = e['geometry'];
      if (geom is! List || geom.length < 2) continue;
      final pts = <LatLng>[
        for (final g in geom)
          if (g is Map && g['lat'] != null && g['lon'] != null)
            LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
      ];
      if (pts.length < 2) continue;
      final tags = <String, String>{};
      final rawTags = e['tags'];
      if (rawTags is Map) {
        rawTags.forEach((k, v) => tags[k.toString()] = v.toString());
      }
      out.add(OsmFeature(
        id: (e['id'] as num?)?.toInt() ?? 0,
        kind: OsmFeature.kindFromTags(tags),
        tags: tags,
        geometry: pts,
      ));
    }
    return out;
  }

  /// Parsea la respuesta de Overpass (`out geom`) a una lista de polylines.
  List<List<LatLng>> _parseStreets(Map<String, dynamic>? data) {
    final elements = (data?['elements'] as List?) ?? const [];
    final streets = <List<LatLng>>[];
    for (final e in elements) {
      if (e is! Map) continue;
      final geom = e['geometry'];
      if (geom is! List || geom.length < 2) continue;
      final pts = <LatLng>[
        for (final g in geom)
          if (g is Map && g['lat'] != null && g['lon'] != null)
            LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
      ];
      if (pts.length >= 2) streets.add(pts);
    }
    return streets;
  }
}
