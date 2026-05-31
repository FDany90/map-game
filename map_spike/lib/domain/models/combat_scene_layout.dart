import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'osm_feature.dart';
import 'osm_scene.dart';
import 'zone_profile.dart';

/// Un punto de la escena en **metros locales ya rotados** (origen = centro de la
/// escena; +x derecha, +y "arriba"/hacia el norte-de-pantalla). La rotación deja
/// la **calle principal vertical** (ver ADR 0007, revisión 2026-05-31).
typedef ScenePoint = ({double x, double y});

/// Una calle lista para dibujar: polyline en metros locales rotados + ancho.
class SceneStreet {
  SceneStreet({
    required this.points,
    required this.type,
    required this.width,
    required this.isMain,
  });

  final List<ScenePoint> points;
  final String type; // valor de highway=
  final double width; // metros, derivado del tipo (OSM casi nunca trae width)
  final bool isMain; // la calle-eje (la que se puso vertical)
}

/// Un edificio para dibujar (top-down con profundidad falsa): footprint en
/// metros locales rotados + nº de pisos (altura de extrusión).
class SceneBuilding {
  SceneBuilding({
    required this.footprint,
    required this.levels,
    required this.inferred,
  });

  final List<ScenePoint> footprint;
  final double levels; // pisos → altura/sombra
  final bool inferred; // true = generado (OSM no lo traía); false = real
}

/// **Layout de la escena de combate** generado desde OSM (Fase 2, ADR 0007).
///
/// Toma la escena cruda de un punto y produce una composición lista para
/// renderizar top-down: proyecta a metros locales, **rota para que la calle
/// principal quede vertical** (aprovecha el cel vertical; los assets no se rotan
/// a ángulos raros), rellena con edificios **inferidos** si OSM no trae
/// footprints, y expone el ángulo del **norte real** para la brújula.
///
/// Lógica pura y **determinista** (siembra el relleno con la posición): el mismo
/// punto genera siempre la misma escena (continuidad + economía por `hexId`).
class CombatSceneLayout {
  CombatSceneLayout({
    required this.streets,
    required this.buildings,
    required this.realBuildingCount,
    required this.realNorthAngleRad,
    required this.character,
    required this.radiusMeters,
  });

  final List<SceneStreet> streets;

  /// Las "paredes" del corredor: **siempre generadas** (ADR 0007 rev). Los
  /// footprints reales de OSM están a media cuadra y dispersos, no sirven como
  /// paredes; ver [realBuildingCount].
  final List<SceneBuilding> buildings;

  /// Cuántos edificios trajo OSM de verdad. **No se dibujan** (se usan solo como
  /// señal de densidad/altura para generar las paredes); se muestra en el panel.
  final int realBuildingCount;

  /// Hacia dónde apunta el **norte real** tras la rotación, en radianes desde el
  /// eje +y (vertical) en sentido horario. Para dibujar la brújula.
  final double realNorthAngleRad;

  final ZoneCharacter character;
  final double radiusMeters;

  static const double _mPerDegLat = 111320.0;

  factory CombatSceneLayout.fromScene(
    OsmScene scene, {
    ZoneProfile? profile,
    double radiusMeters = 70,
  }) {
    final zone = profile ?? ZoneProfile.fromScene(scene);
    final c = scene.center;
    final mPerDegLon = _mPerDegLat * math.cos(c.latitude * math.pi / 180);

    ScenePoint toLocal(LatLng p) => (
          x: (p.longitude - c.longitude) * mPerDegLon,
          y: (p.latitude - c.latitude) * _mPerDegLat,
        );

    // 1) Calle principal: mayor jerarquía cerca del centro, desempata la más larga.
    final streetsLocal = [
      for (final f in scene.streets)
        (feature: f, pts: [for (final p in f.geometry) toLocal(p)]),
    ];
    final main = _pickMainStreet(streetsLocal);

    // 2) Rotación que vuelve vertical la calle principal (su dirección → eje +y).
    // rot = π/2 − φ, con φ = ángulo estándar de la calle desde +x; rotación
    // antihoraria estándar que lleva el vector de la calle a apuntar a +y.
    final rot = main == null ? 0.0 : (math.pi / 2 - _streetAngle(main.pts));
    final cosR = math.cos(rot), sinR = math.sin(rot);
    ScenePoint rotate(ScenePoint p) => (
          x: p.x * cosR - p.y * sinR,
          y: p.x * sinR + p.y * cosR,
        );

    // 3) Calles rotadas + ancho por tipo.
    final outStreets = <SceneStreet>[
      for (final s in streetsLocal)
        SceneStreet(
          points: [for (final p in s.pts) rotate(p)],
          type: s.feature.tags['highway'] ?? 'residential',
          width: _streetWidth(s.feature.tags),
          isMain: identical(s, main),
        ),
    ];

    // 4) Paredes del corredor: SIEMPRE procedurales (ADR 0007 rev / 2026-05-31).
    // Los footprints reales de OSM están a media cuadra y dispersos: no sirven
    // como "paredes". Se usan solo como SEÑAL — cuántos hay (densidad) y qué
    // altura declaran (pisos). El dibujo es generado y determinista.
    final realCount = scene.buildings.length;
    final realAvgLevels = _avgExplicitLevels(scene.buildings);
    final crossStreets = [for (final s in outStreets) if (!s.isMain) s];
    final walls = _inferBuildings(
      zone: zone,
      radius: radiusMeters,
      seedLat: c.latitude,
      seedLon: c.longitude,
      realCount: realCount,
      realAvgLevels: realAvgLevels,
      crossStreets: crossStreets,
    );

    // 5) Norte real tras rotar: el norte era +y; ahora apunta a `rot`.
    return CombatSceneLayout(
      streets: outStreets,
      buildings: walls,
      realBuildingCount: realCount,
      realNorthAngleRad: rot,
      character: zone.character,
      radiusMeters: radiusMeters,
    );
  }

  // --- selección de calle principal ---

  static ({OsmFeature feature, List<ScenePoint> pts})? _pickMainStreet(
    List<({OsmFeature feature, List<ScenePoint> pts})> streets,
  ) {
    if (streets.isEmpty) return null;
    int rank(String? h) => switch (h) {
          'motorway' || 'trunk' => 5,
          'primary' => 4,
          'secondary' => 3,
          'tertiary' => 2,
          'residential' || 'living_street' => 1,
          _ => 0,
        };
    ({OsmFeature feature, List<ScenePoint> pts})? best;
    var bestScore = -1.0;
    for (final s in streets) {
      final score = rank(s.feature.tags['highway']) * 100000 + _length(s.pts);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  /// Ángulo estándar (rad) de la dirección de la calle desde el eje +x
  /// (antihorario), usando los puntos extremos.
  static double _streetAngle(List<ScenePoint> pts) {
    final a = pts.first, b = pts.last;
    return math.atan2(b.y - a.y, b.x - a.x);
  }

  static double _streetWidth(Map<String, String> tags) {
    final w = double.tryParse(tags['width'] ?? '');
    if (w != null) return w.clamp(2.0, 40.0);
    final lanes = double.tryParse(tags['lanes'] ?? '');
    if (lanes != null) return (lanes * 3.2).clamp(3.0, 40.0);
    return switch (tags['highway']) {
      'motorway' || 'trunk' => 16,
      'primary' => 14,
      'secondary' => 11,
      'tertiary' => 9,
      'residential' || 'living_street' => 7,
      'service' => 4,
      'footway' || 'path' || 'steps' || 'pedestrian' || 'cycleway' => 2.5,
      _ => 6,
    };
  }

  /// Pisos que el edificio **declara explícitamente** en OSM (levels o height),
  /// o `null` si no dice nada. Sirve de señal de altura, no para dibujarlo.
  static double? _explicitLevels(OsmFeature f) {
    final lv = double.tryParse(f.tags['building:levels'] ?? '');
    if (lv != null && lv > 0) return lv;
    final h = double.tryParse(f.tags['height'] ?? '');
    if (h != null && h > 0) return (h / 3).clamp(1, 60);
    return null;
  }

  /// Promedio de pisos declarados por los edificios reales (o `null` si ninguno
  /// declara). Es la señal de altura para las paredes generadas.
  static double? _avgExplicitLevels(List<OsmFeature> buildings) {
    var sum = 0.0;
    var n = 0;
    for (final f in buildings) {
      final lv = _explicitLevels(f);
      if (lv != null) {
        sum += lv;
        n++;
      }
    }
    return n == 0 ? null : sum / n;
  }

  static double _defaultLevels(ZoneCharacter character) => switch (character) {
        ZoneCharacter.denseUrban => 8,
        ZoneCharacter.residential => 2,
        ZoneCharacter.roadCorridor => 1,
        ZoneCharacter.openGreen => 0,
        ZoneCharacter.rural => 1,
        ZoneCharacter.emptyArea => 0,
        ZoneCharacter.unknown => 2,
      };

  // --- relleno de edificios inferidos a los lados de la calle principal ---

  static List<SceneBuilding> _inferBuildings({
    required ZoneProfile zone,
    required double radius,
    required double seedLat,
    required double seedLon,
    required int realCount,
    required double? realAvgLevels,
    required List<SceneStreet> crossStreets,
  }) {
    // Altura típica: la que declara OSM si la hay; si no, la de la zona.
    final baseLevels = realAvgLevels ?? _defaultLevels(zone.character);
    if (baseLevels <= 0) return const []; // parque / vacío: sin edificios

    // Más edificios reales detectados → corredor más lleno (menos huecos).
    final densityBoost = (realCount / 20).clamp(0.0, 1.0);
    final dense = zone.character == ZoneCharacter.denseUrban || baseLevels >= 5;

    final rng = _SeededRng(_seedFrom(seedLat, seedLon));
    final parcel = dense ? 16.0 : 12.0; // largo de lote a lo largo de la calle
    final depth = dense ? 18.0 : 10.0; // fondo del edificio
    final setback = (dense ? 7.0 : 5.0) + baseLevels * 0.15; // separación calle
    final gapProb = (dense ? 0.12 : 0.20) * (1 - 0.6 * densityBoost);

    final out = <SceneBuilding>[];
    // La calle principal quedó vertical (eje y): lotes a izquierda y derecha.
    for (var side = -1; side <= 1; side += 2) {
      final baseX = side * setback;
      for (var y = -radius + parcel / 2; y < radius; y += parcel) {
        if (rng.next() < gapProb) continue; // hueco/baldío ocasional
        final jitterX = (rng.next() - 0.5) * 3;
        final w = parcel * (0.7 + rng.next() * 0.25);
        final d = depth * (0.8 + rng.next() * 0.4);
        final x0 = side > 0 ? baseX + jitterX : baseX - jitterX - d;
        final y0 = y - w / 2;
        // Carve-out de cruces: si el lote pisa una calle transversal, lo salteo
        // (deja la intersección despejada — las esquinas son escenarios clave).
        if (_touchesAnyStreet(x0 + d / 2, y0 + w / 2, crossStreets)) continue;
        final lv =
            (baseLevels * (0.6 + rng.next() * 0.9)).clamp(1, 60).toDouble();
        out.add(SceneBuilding(
          footprint: [
            (x: x0, y: y0),
            (x: x0 + d, y: y0),
            (x: x0 + d, y: y0 + w),
            (x: x0, y: y0 + w),
          ],
          levels: lv,
          inferred: true,
        ));
      }
    }
    return out;
  }

  /// ¿El punto (x,y) cae sobre alguna de estas calles (dentro de su ancho)?
  static bool _touchesAnyStreet(double x, double y, List<SceneStreet> streets) {
    for (final s in streets) {
      final half = s.width / 2 + 2;
      for (var i = 0; i < s.points.length - 1; i++) {
        if (_distToSeg(x, y, s.points[i], s.points[i + 1]) < half) return true;
      }
    }
    return false;
  }

  static double _distToSeg(double px, double py, ScenePoint a, ScenePoint b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) {
      final ex = px - a.x, ey = py - a.y;
      return math.sqrt(ex * ex + ey * ey);
    }
    final t = (((px - a.x) * dx + (py - a.y) * dy) / len2).clamp(0.0, 1.0);
    final cx = a.x + t * dx, cy = a.y + t * dy;
    final ex = px - cx, ey = py - cy;
    return math.sqrt(ex * ex + ey * ey);
  }

  static int _seedFrom(double lat, double lon) {
    final a = (lat * 100000).round();
    final b = (lon * 100000).round();
    return (a * 73856093) ^ (b * 19349663);
  }

  static double _length(List<ScenePoint> pts) {
    var sum = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final dx = pts[i + 1].x - pts[i].x, dy = pts[i + 1].y - pts[i].y;
      sum += math.sqrt(dx * dx + dy * dy);
    }
    return sum;
  }
}

/// PRNG lineal simple y **determinista** (no usa Random global). Doubles en [0,1).
class _SeededRng {
  _SeededRng(int seed) : _state = (seed & 0x7fffffff) | 1;
  int _state;

  double next() {
    _state = (_state * 1664525 + 1013904223) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}
