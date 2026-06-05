import 'package:latlong2/latlong.dart';

import '../../domain/models/map_marker.dart';

/// Genera las **amenazas del mapa** (grupos de zombies, y a futuro boss/dungeon)
/// de forma **determinista** a partir de la posición — **sin guardar nada** en una
/// BD (doc 16: generación lazy + gradiente determinista). El mismo lugar produce
/// la misma amenaza para todos los jugadores y se puede calcular sin haberlo
/// "materializado".
///
/// Prototipo: grilla simple en lat/lng (sin H3 todavía; H3 = Etapa 2). Lógica pura
/// y testeable (no toca UI ni red).
class ThreatService {
  ThreatService({required this.spawn});

  /// Punto de inicio del jugador: ancla del **gradiente de dificultad** (cerca =
  /// fácil, lejos = difícil).
  final LatLng spawn;

  /// Tamaño de celda de la grilla (~155 m por celda).
  static const double cellDeg = 0.0014;

  /// % de celdas que tienen una amenaza (sparse: la mayoría no tiene nada).
  static const int _spawnPct = 18;

  /// Cuántas celdas alrededor del centro se generan (radio en celdas).
  static const int _rings = 7;

  static const Distance _distance = Distance();

  /// Amenazas alrededor de [center]. Recorre las celdas vecinas y, para cada una,
  /// un **hash determinista** del id de celda decide si hay amenaza, dónde (jitter
  /// determinista dentro de la celda) y de qué dificultad/composición.
  List<MapMarker> threatsAround(LatLng center) {
    final out = <MapMarker>[];
    final clat = (center.latitude / cellDeg).floor();
    final clng = (center.longitude / cellDeg).floor();
    for (var dla = -_rings; dla <= _rings; dla++) {
      for (var dlo = -_rings; dlo <= _rings; dlo++) {
        final la = clat + dla, lo = clng + dlo;
        final h = _hash(la, lo);
        if (h % 100 >= _spawnPct) continue; // celda sin amenaza
        final jLat = ((h >> 8) & 0x3f) / 64.0; // 0..1 determinista
        final jLng = ((h >> 14) & 0x3f) / 64.0;
        final pos = LatLng(
          (la + 0.2 + jLat * 0.6) * cellDeg,
          (lo + 0.2 + jLng * 0.6) * cellDeg,
        );
        final diff = _difficulty(pos, h);
        out.add(MapMarker(
          id: 'z:$la:$lo',
          position: pos,
          kind: MarkerKind.zombieGroup,
          difficulty: diff,
          enemies: _enemies(diff),
        ));
      }
    }
    return out;
  }

  /// Gradiente: cerca del spawn = fácil; +1 cada ~500 m, con textura ±1 por celda.
  /// (Futuro: pesar también la densidad urbana del OSM — doc 16.)
  int _difficulty(LatLng pos, int h) {
    final meters = _distance(spawn, pos);
    var d = 1 + (meters / 500).floor();
    d += ((h >> 20) % 3) - 1; // textura determinista ±1
    return d.clamp(1, 5);
  }

  /// Composición de enemigos según la dificultad (más difícil = más y peores).
  List<EnemyGroup> _enemies(int diff) {
    final list = <EnemyGroup>[EnemyGroup(EnemyType.caminante, 8 + diff * 3)];
    if (diff >= 3) list.add(EnemyGroup(EnemyType.corredor, 2 + diff));
    if (diff >= 5) list.add(const EnemyGroup(EnemyType.tanque, 2));
    return list;
  }

  /// Hash determinista (FNV-1a sobre los índices de celda). Estable por celda.
  int _hash(int a, int b) {
    var h = 0x811c9dc5;
    for (final part in [a & 0xffff, (a >> 16) & 0xffff, b & 0xffff, (b >> 16) & 0xffff]) {
      h = ((h ^ part) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}
