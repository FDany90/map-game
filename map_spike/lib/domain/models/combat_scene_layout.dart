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
    // rot = π/2 − φ, con φ = ángulo estándar de la calle desde +x.
    // **Normalizada a (−π/2, π/2]**: una calle es una línea sin sentido, pero OSM
    // guarda sus nodos en un orden arbitrario; si vino de norte→sur, φ apunta
    // hacia abajo y rot daría ~π (la escena entera dada vuelta, norte abajo).
    // Rotar 180° de más deja la calle igual de vertical, así que elegimos la
    // rotación de menor magnitud → el norte nunca se aleja más de 90° de arriba.
    final rot = main == null ? 0.0 : _normalizeHalfPi(math.pi / 2 - _localStreetAngle(main.pts));
    final cosR = math.cos(rot), sinR = math.sin(rot);
    ScenePoint rotate(ScenePoint p) => (
          x: p.x * cosR - p.y * sinR,
          y: p.x * sinR + p.y * cosR,
        );

    // 2b) **Re-centrar la calle principal en x=0.** El origen es el punto que el
    // jugador tocó, que casi nunca cae exacto sobre el eje de la calle. Sin esto,
    // la calle se dibuja en su x real pero los edificios se generan simétricos
    // alrededor de x=0 (el click) → quedan desalineados respecto a la calle.
    // Tomamos el x (ya rotado) del punto de la calle más cercano al jugador y lo
    // restamos, de modo que la calle pase por x=0 justo donde está el jugador.
    final mainRotated = main == null ? null : [for (final p in main.pts) rotate(p)];
    final mainX = mainRotated == null ? 0.0 : _xNearestToOrigin(mainRotated);
    ScenePoint project(ScenePoint p) {
      final r = rotate(p);
      return (x: r.x - mainX, y: r.y);
    }

    // 3) Calles proyectadas (rotadas + re-centradas) + ancho por tipo.
    final outStreets = <SceneStreet>[
      for (final s in streetsLocal)
        SceneStreet(
          points: [for (final p in s.pts) project(p)],
          type: s.feature.tags['highway'] ?? 'residential',
          width: _streetWidth(s.feature.tags),
          isMain: identical(s, main),
        ),
    ];
    final mainWidth =
        main == null ? 0.0 : _streetWidth(main.feature.tags);

    // 4) Paredes del corredor: SIEMPRE procedurales (ADR 0007 rev / 2026-05-31).
    // Los footprints reales de OSM están a media cuadra y dispersos: no sirven
    // como "paredes". Se usan solo como SEÑAL — cuántos hay (densidad) y qué
    // altura declaran (pisos). El dibujo es generado y determinista.
    final realCount = scene.buildings.length;
    final realAvgLevels = _avgExplicitLevels(scene.buildings);
    final crossStreets = [for (final s in outStreets) if (!s.isMain) s];
    final mainStreetPts = main == null
        ? const <ScenePoint>[]
        : outStreets.firstWhere((s) => s.isMain).points;
    final walls = _inferBuildings(
      zone: zone,
      radius: radiusMeters,
      seedLat: c.latitude,
      seedLon: c.longitude,
      realCount: realCount,
      realAvgLevels: realAvgLevels,
      crossStreets: crossStreets,
      mainStreet: mainStreetPts,
      mainHalfWidth: mainWidth / 2,
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

  /// Ángulo (rad) de la dirección de la calle **en el tramo más cercano al
  /// jugador** (origen), no de la cuerda extremo-a-extremo. Así la calle queda
  /// vertical justo donde está parado el jugador, aunque la calle se curve.
  /// (Bug 2026-05-31: usar los extremos dejaba la calle inclinada.)
  static double _localStreetAngle(List<ScenePoint> pts) {
    if (pts.length < 2) return math.pi / 2;
    var bestD2 = double.infinity;
    var bestAng = math.pi / 2;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final dx = b.x - a.x, dy = b.y - a.y;
      final len2 = dx * dx + dy * dy;
      if (len2 == 0) continue;
      final t = ((-a.x * dx - a.y * dy) / len2).clamp(0.0, 1.0);
      final cx = a.x + t * dx, cy = a.y + t * dy;
      final d2 = cx * cx + cy * cy; // distancia² del segmento al origen
      if (d2 < bestD2) {
        bestD2 = d2;
        bestAng = math.atan2(dy, dx);
      }
    }
    return bestAng;
  }

  /// Lleva un ángulo al rango (−π/2, π/2] sumando/restando π. Rotar la escena π
  /// de más deja la calle igual de vertical pero invierte el norte; con esto
  /// elegimos siempre la rotación mínima (norte arriba).
  static double _normalizeHalfPi(double a) {
    var x = a;
    while (x > math.pi / 2) {
      x -= math.pi;
    }
    while (x <= -math.pi / 2) {
      x += math.pi;
    }
    return x;
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
    required List<ScenePoint> mainStreet,
    required double mainHalfWidth,
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
    // Separación calle↔edificio: vereda + media calzada de la calle principal,
    // para que los lotes nunca se monten sobre el asfalto.
    final setback =
        math.max((dense ? 7.0 : 5.0) + baseLevels * 0.15, mainHalfWidth + 2.5);
    final gapProb = (dense ? 0.12 : 0.20) * (1 - 0.6 * densityBoost);

    // Espina = la calle principal real, extendida a sus extremos para cubrir
    // toda la escena. Los lotes se colocan **siguiendo esta polilínea** (no en
    // columnas verticales fijas): así abrazan la calle aunque tenga inclinación
    // o curva, en vez de despegarse arriba/abajo. (Bug 2026-05-31.)
    final spine = _buildSpine(mainStreet, radius);
    final samples = _samplesAlong(spine, parcel, parcel / 2);

    final out = <SceneBuilding>[];
    for (final s in samples) {
      // Descarto muestras fuera del cuadro (la espina se extendió de más).
      if (s.pos.x.abs() > radius * 1.2 || s.pos.y.abs() > radius * 1.05) {
        continue;
      }
      // Normal izquierda a la dirección local de la calle.
      final nx = -s.dir.y, ny = s.dir.x;
      for (var side = -1; side <= 1; side += 2) {
        if (rng.next() < gapProb) continue; // hueco/baldío ocasional
        final w = parcel * (0.7 + rng.next() * 0.25); // a lo largo de la calle
        final d = depth * (0.8 + rng.next() * 0.4); // fondo (perpendicular)
        final jitter = (rng.next() - 0.5) * 2;
        final off = setback + d / 2 + jitter; // distancia al eje de la calle
        final cx = s.pos.x + nx * side * off;
        final cy = s.pos.y + ny * side * off;
        // Ejes del lote: mitad a lo largo de la calle (dir) y mitad al fondo (n).
        final ax = s.dir.x * (w / 2), ay = s.dir.y * (w / 2);
        final bx = nx * (d / 2), by = ny * (d / 2);
        final footprint = <ScenePoint>[
          (x: cx - ax - bx, y: cy - ay - by),
          (x: cx + ax - bx, y: cy + ay - by),
          (x: cx + ax + bx, y: cy + ay + by),
          (x: cx - ax + bx, y: cy - ay + by),
        ];
        // Carve-out de cruces: si alguna esquina pisa una calle transversal, lo
        // salteo (deja la intersección despejada — las esquinas son clave).
        if (footprint.any((p) => _touchesAnyStreet(p.x, p.y, crossStreets))) {
          continue;
        }
        final lv =
            (baseLevels * (0.6 + rng.next() * 0.9)).clamp(1, 60).toDouble();
        out.add(SceneBuilding(footprint: footprint, levels: lv, inferred: true));
      }
    }
    return out;
  }

  /// La calle principal real extendida por ambos extremos (siguiendo la
  /// dirección de su primer/último segmento) para cubrir toda la escena. Si no
  /// hay calle, devuelve un eje vertical por el origen.
  static List<ScenePoint> _buildSpine(List<ScenePoint> main, double radius) {
    if (main.length < 2) {
      return [(x: 0.0, y: -radius), (x: 0.0, y: radius)];
    }
    final out = [...main];
    final ext = radius * 2;
    final a0 = out[0], a1 = out[1];
    final d0 = _unit(a0.x - a1.x, a0.y - a1.y); // hacia afuera del inicio
    out.insert(0, (x: a0.x + d0.x * ext, y: a0.y + d0.y * ext));
    final b1 = out[out.length - 1], b0 = out[out.length - 2];
    final d1 = _unit(b1.x - b0.x, b1.y - b0.y); // hacia afuera del final
    out.add((x: b1.x + d1.x * ext, y: b1.y + d1.y * ext));
    return out;
  }

  /// Muestrea una polilínea cada [step] metros de arco, arrancando a [start] del
  /// inicio. Devuelve la posición y la **dirección unitaria local** en cada paso.
  static List<({ScenePoint pos, ScenePoint dir})> _samplesAlong(
    List<ScenePoint> pts,
    double step,
    double start,
  ) {
    final out = <({ScenePoint pos, ScenePoint dir})>[];
    var dist = start; // metros hasta la próxima muestra
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final dx = b.x - a.x, dy = b.y - a.y;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;
      final ux = dx / segLen, uy = dy / segLen;
      var t = dist;
      while (t <= segLen) {
        out.add((pos: (x: a.x + ux * t, y: a.y + uy * t), dir: (x: ux, y: uy)));
        t += step;
      }
      dist = t - segLen; // arrastro el resto al próximo segmento
    }
    return out;
  }

  static ScenePoint _unit(double x, double y) {
    final len = math.sqrt(x * x + y * y);
    return len == 0 ? (x: 0.0, y: 1.0) : (x: x / len, y: y / len);
  }

  /// x del punto de la polilínea [pts] más cercano al origen (0,0). Sirve para
  /// re-centrar la calle principal en x=0 justo donde está el jugador.
  static double _xNearestToOrigin(List<ScenePoint> pts) {
    if (pts.length == 1) return pts.first.x;
    var bestD2 = double.infinity;
    var bestX = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final dx = b.x - a.x, dy = b.y - a.y;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0
          ? 0.0
          : ((-a.x * dx - a.y * dy) / len2).clamp(0.0, 1.0);
      final cx = a.x + t * dx, cy = a.y + t * dy;
      final d2 = cx * cx + cy * cy;
      if (d2 < bestD2) {
        bestD2 = d2;
        bestX = cx;
      }
    }
    return bestX;
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
