import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/osm_feature.dart';
import '../../domain/models/osm_scene.dart';
import '../../domain/models/streets_source.dart';
import '../services/overpass_service.dart';

/// Fuente única de verdad de la **escena OSM cruda** (calles + edificios +
/// áreas con sus tags) de un punto.
///
/// Mismo patrón de resiliencia que `StreetsRepository` (best-practice: la
/// caché/offline viven en el repositorio): primero la **caché en disco**
/// (persistente, offline, respeta el fair-use de Overpass), si no, **Overpass**.
/// A diferencia de las calles, acá **no hay fallback sintético**: una escena
/// inventada no sirve para inspeccionar datos reales, así que se propaga el error.
class OsmSceneRepository {
  OsmSceneRepository({required OverpassService overpass})
      : _overpass = overpass; // ignore: prefer_initializing_formals

  final OverpassService _overpass;

  Future<OsmScene> getSceneAround(
    LatLng center, {
    double radiusMeters = 150,
  }) async {
    // 1) Caché en disco.
    final cached = await _readCache(center, radiusMeters);
    if (cached != null && cached.isNotEmpty) {
      return OsmScene(
        center: center,
        radiusMeters: radiusMeters,
        features: cached,
        source: StreetsSource.cache,
      );
    }
    // 2) Overpass (el servicio ya prueba endpoint + mirror; lanza si falla).
    final fresh =
        await _overpass.fetchSceneAround(center, radiusMeters: radiusMeters);
    await _writeCache(center, radiusMeters, fresh);
    return OsmScene(
      center: center,
      radiusMeters: radiusMeters,
      features: fresh,
      source: StreetsSource.overpass,
    );
  }

  // --- Caché en disco (JSON en el dir de documentos, persistente) ---

  Future<File> _cacheFile(LatLng c, double radius) async {
    final dir = await getApplicationDocumentsDirectory();
    final key = 'scene_${c.latitude.toStringAsFixed(4)}_'
        '${c.longitude.toStringAsFixed(4)}_${radius.round()}.json';
    return File('${dir.path}/$key');
  }

  Future<List<OsmFeature>?> _readCache(LatLng c, double radius) async {
    try {
      final file = await _cacheFile(c, radius);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString()) as List;
      return [
        for (final f in raw) OsmFeature.fromJson(f as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('OsmSceneRepository: caché ilegible, la ignoro. $e');
      return null;
    }
  }

  Future<void> _writeCache(
    LatLng c,
    double radius,
    List<OsmFeature> features,
  ) async {
    try {
      final file = await _cacheFile(c, radius);
      await file.writeAsString(
        jsonEncode([for (final f in features) f.toJson()]),
      );
    } catch (e) {
      debugPrint('OsmSceneRepository: no pude escribir la caché. $e');
    }
  }
}
