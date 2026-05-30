import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/streets_source.dart';
import '../services/overpass_service.dart';

/// Fuente única de verdad de la geometría de calles.
///
/// Orquesta la resiliencia (best-practice: la caché/offline/fallback viven en el
/// repositorio, no en el servicio ni en el ViewModel):
///   1. **caché en disco** (persistente, funciona offline y respeta el fair-use
///      de Overpass: se baja una vez por área),
///   2. si no hay caché → **Overpass** (con mirror, vía [OverpassService]),
///   3. si Overpass falla → **calles sintéticas de fallback** (no se cachean).
class StreetsRepository {
  StreetsRepository({required OverpassService overpass})
      : _overpass = overpass; // ignore: prefer_initializing_formals

  final OverpassService _overpass;

  Future<({List<List<LatLng>> streets, StreetsSource source})> getStreetsAround(
    LatLng center, {
    double radiusMeters = 300,
  }) async {
    // 1) Caché en disco.
    final cached = await _readCache(center, radiusMeters);
    if (cached != null && cached.isNotEmpty) {
      return (streets: cached, source: StreetsSource.cache);
    }
    // 2) Overpass (el servicio ya prueba endpoint + mirror).
    try {
      final fresh =
          await _overpass.fetchStreetsAround(center, radiusMeters: radiusMeters);
      await _writeCache(center, radiusMeters, fresh); // cachear para la próxima
      return (streets: fresh, source: StreetsSource.overpass);
    } catch (e) {
      // 3) Fallback sintético (no se cachea: no son calles reales).
      debugPrint('StreetsRepository: Overpass falló, uso fallback. $e');
      return (
        streets: _fallbackStreets(center, radiusMeters),
        source: StreetsSource.fallback,
      );
    }
  }

  // --- Caché en disco (JSON en el dir de documentos, persistente) ---

  Future<File> _cacheFile(LatLng c, double radius) async {
    final dir = await getApplicationDocumentsDirectory();
    final key = 'streets_${c.latitude.toStringAsFixed(4)}_'
        '${c.longitude.toStringAsFixed(4)}_${radius.round()}.json';
    return File('${dir.path}/$key');
  }

  Future<List<List<LatLng>>?> _readCache(LatLng c, double radius) async {
    try {
      final file = await _cacheFile(c, radius);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString()) as List;
      return [
        for (final street in raw)
          [
            for (final p in (street as List))
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
      ];
    } catch (e) {
      debugPrint('StreetsRepository: caché ilegible, la ignoro. $e');
      return null;
    }
  }

  Future<void> _writeCache(
    LatLng c,
    double radius,
    List<List<LatLng>> streets,
  ) async {
    try {
      final file = await _cacheFile(c, radius);
      final data = [
        for (final street in streets)
          [
            for (final p in street) [p.latitude, p.longitude],
          ],
      ];
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('StreetsRepository: no pude escribir la caché. $e');
    }
  }

  // --- Fallback: rayos desde el borde del radio hacia el centro (base) ---

  List<List<LatLng>> _fallbackStreets(LatLng c, double radius) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = 111320.0 * math.cos(c.latitude * math.pi / 180);
    final streets = <List<LatLng>>[];
    for (var deg = 0; deg < 360; deg += 45) {
      final rad = deg * math.pi / 180;
      final line = <LatLng>[];
      for (var d = radius; d >= 0; d -= radius / 4) {
        final dx = d * math.cos(rad);
        final dy = d * math.sin(rad);
        line.add(LatLng(
          c.latitude + dy / metersPerDegLat,
          c.longitude + dx / metersPerDegLon,
        ));
      }
      streets.add(line); // de afuera (d=radius) hacia el centro (d=0)
    }
    return streets;
  }
}
