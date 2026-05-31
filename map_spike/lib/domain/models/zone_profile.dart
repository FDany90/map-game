import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'osm_feature.dart';
import 'osm_scene.dart';

/// Carácter urbano inferido de un punto. Como OSM casi nunca trae edificios
/// (ver `docs/17-inferencia-morfologia-urbana.md`), el generador de escenas
/// **infiere** la morfología desde las **calles** (que sí vienen) para decidir
/// qué dibujar: torres, casas bajas, verde, descampado o una ruta cruzando.
enum ZoneCharacter {
  denseUrban('Denso urbano', 'torres / edificios altos'),
  residential('Barrio de casas', 'casas bajas / PH (1-3 pisos)'),
  openGreen('Parque / abierto', 'verde, árboles, pocos edificios'),
  roadCorridor('Ruta / corredor', 'una calle cruzando, casi sin construcción'),
  rural('Rural / descampado', 'casas dispersas, mucho terreno'),
  emptyArea('Vacío / sin datos', 'agua, desierto o bosque — nada mapeado'),
  unknown('Indeterminado', 'datos insuficientes');

  const ZoneCharacter(this.label, this.hint);
  final String label;
  final String hint;
}

/// Resultado de clasificar un punto: el carácter + las señales que lo sustentan
/// (para mostrar "por qué" y para alimentar la generación procedural).
///
/// **Determinista:** depende solo de la geometría/tags de OSM, no de azar ni del
/// momento — el mismo punto da siempre el mismo perfil (clave para la economía por
/// `hexId`, ver `docs/16-modelo-hexagonos-bd.md`).
class ZoneProfile {
  ZoneProfile({
    required this.character,
    required this.streetCount,
    required this.streetLengthMeters,
    required this.streetDensity,
    required this.majorRoads,
    required this.residentialRoads,
    required this.pedestrianPaths,
    required this.minorRoads,
    required this.hasBuildings,
    required this.hasGreen,
  });

  final ZoneCharacter character;

  /// Nº de calles cercanas. Overpass (`around:`) ya filtra por cercanía, así que
  /// es la **cantidad real de calles** en el área = proxy de trama urbana.
  final int streetCount;

  /// Longitud de calle **recortada al radio** (m). A diferencia del conteo, acá
  /// sí se recorta porque `out geom` trae la calle entera (km), no solo el tramo
  /// dentro del círculo — sumarla cruda inflaba la densidad (bug corregido).
  final double streetLengthMeters;

  /// Densidad: metros de calle (recortada) por hectárea. Proxy de "qué tan denso".
  final double streetDensity;

  final int majorRoads; // motorway/trunk/primary/secondary (+ links)
  final int residentialRoads; // residential/living_street
  final int pedestrianPaths; // footway/path/steps/pedestrian/cycleway/track
  final int minorRoads; // service/unclassified/...
  final bool hasBuildings;
  final bool hasGreen; // leisure / áreas verdes

  /// Clasifica una escena OSM. Heurística basada en calles (ver doc 17).
  factory ZoneProfile.fromScene(OsmScene scene) {
    var major = 0, residential = 0, pedestrian = 0, minor = 0;
    var clippedLength = 0.0;

    final c = scene.center;
    final mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(c.latitude * math.pi / 180);
    // lat/lon → metros locales relativos al centro (origen).
    math.Point<double> toLocal(LatLng p) => math.Point(
          (p.longitude - c.longitude) * mPerDegLon,
          (p.latitude - c.latitude) * mPerDegLat,
        );

    for (final f in scene.streets) {
      clippedLength += _clippedLength(f, toLocal, scene.radiusMeters);
      switch (f.tags['highway']) {
        case 'motorway':
        case 'trunk':
        case 'primary':
        case 'secondary':
        case 'motorway_link':
        case 'trunk_link':
        case 'primary_link':
        case 'secondary_link':
          major++;
        case 'residential':
        case 'living_street':
          residential++;
        case 'footway':
        case 'path':
        case 'steps':
        case 'pedestrian':
        case 'cycleway':
        case 'track':
          pedestrian++;
        default:
          minor++;
      }
    }

    final streetCount = scene.streets.length;
    final areaHectares =
        math.max(math.pi * scene.radiusMeters * scene.radiusMeters, 1) / 10000;
    final density = clippedLength / areaHectares;

    final hasBuildings = scene.buildings.isNotEmpty;
    final hasGreen = scene.areas.isNotEmpty;
    final vehicleRoads = major + residential + minor;

    final character = _classify(
      streetCount: streetCount,
      major: major,
      residential: residential,
      pedestrian: pedestrian,
      vehicleRoads: vehicleRoads,
      density: density,
      hasGreen: hasGreen,
      buildingCount: scene.buildings.length,
    );

    return ZoneProfile(
      character: character,
      streetCount: streetCount,
      streetLengthMeters: clippedLength,
      streetDensity: density,
      majorRoads: major,
      residentialRoads: residential,
      pedestrianPaths: pedestrian,
      minorRoads: minor,
      hasBuildings: hasBuildings,
      hasGreen: hasGreen,
    );
  }

  static ZoneCharacter _classify({
    required int streetCount,
    required int major,
    required int residential,
    required int pedestrian,
    required int vehicleRoads,
    required double density,
    required bool hasGreen,
    required int buildingCount,
  }) {
    final hasBuildings = buildingCount > 0;

    // 1) Sin ninguna calle.
    if (streetCount == 0) {
      if (hasGreen) return ZoneCharacter.openGreen;
      // Nada mapeado (ni calles, ni verde, ni edificios): mar, desierto, bosque
      // sin caminos. Es info válida (zona vacía), no un error. Ver doc 17.
      if (!hasBuildings) return ZoneCharacter.emptyArea;
      return ZoneCharacter.unknown;
    }

    // 2) Parque / abierto: hay verde y dominan los senderos peatonales, con
    //    muy pocas calles para autos.
    if (hasGreen && pedestrian >= 1 && pedestrian >= vehicleRoads * 2 &&
        vehicleRoads <= 2) {
      return ZoneCharacter.openGreen;
    }

    // 3) Ruta / corredor: hay una avenida (o pocas calles) pero NADA alrededor
    //    — sin edificios, sin trama, sin verde. (El bug: antes esto era "denso".)
    if (major >= 1 && streetCount <= 2 && !hasBuildings && !hasGreen) {
      return ZoneCharacter.roadCorridor;
    }

    // 4) Rural / descampado: muy pocas calles, sin avenidas ni construcción.
    if (streetCount <= 2 && major == 0 && !hasBuildings && !hasGreen) {
      return ZoneCharacter.rural;
    }

    // 5) Denso urbano: requiere TRAMA (muchas calles) y/o edificios mapeados —
    //    no basta una sola avenida.
    if (buildingCount >= 6 ||
        (major >= 1 && streetCount >= 5) ||
        streetCount >= 10) {
      return ZoneCharacter.denseUrban;
    }

    // 6) Barrio de casas: calles residenciales o una trama modesta.
    if (residential >= 1 || streetCount >= 3) {
      return ZoneCharacter.residential;
    }

    // 7) Resto: poca calle sin avenidas → rural; si no, indeterminado.
    if (density < 150 && major == 0) return ZoneCharacter.rural;
    return ZoneCharacter.unknown;
  }

  /// Longitud del [street] **dentro** del círculo de radio [radius] (m),
  /// recortando cada segmento a la intersección con el círculo (centro = origen
  /// en coords locales vía [toLocal]). Evita contar los km de una avenida que
  /// solo cruza el área.
  static double _clippedLength(
    OsmFeature street,
    math.Point<double> Function(LatLng) toLocal,
    double radius,
  ) {
    final pts = [for (final p in street.geometry) toLocal(p)];
    final r2 = radius * radius;
    var sum = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final dx = b.x - a.x, dy = b.y - a.y;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;
      // Intersección del segmento P(t)=a+t·(b-a) con |P|=radius, t∈[0,1].
      final aa = dx * dx + dy * dy;
      final bb = 2 * (a.x * dx + a.y * dy);
      final cc = a.x * a.x + a.y * a.y - r2;
      final disc = bb * bb - 4 * aa * cc;
      if (disc <= 0) {
        // Sin cruce real: o todo dentro (cc<=0) o todo fuera.
        if (cc <= 0) sum += segLen;
        continue;
      }
      final sq = math.sqrt(disc);
      var t1 = (-bb - sq) / (2 * aa);
      var t2 = (-bb + sq) / (2 * aa);
      final lo = math.max(0.0, math.min(t1, t2));
      final hi = math.min(1.0, math.max(t1, t2));
      if (hi > lo) sum += (hi - lo) * segLen;
    }
    return sum;
  }
}
