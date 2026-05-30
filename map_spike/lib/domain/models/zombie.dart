import 'package:latlong2/latlong.dart';

/// Un zombie que camina por una calle hacia la base (representación VISUAL del
/// farmeo; ver `docs/11-zombies-calles-cost.md`). No es simulación: posición
/// aproximada caminando a lo largo de una polyline.
class Zombie {
  Zombie({required this.id, required this.path})
      : assert(path.length >= 2),
        segment = 0,
        tInSegment = 0,
        position = path.first;

  final int id;

  /// Polyline a seguir, ordenada de afuera (spawn) hacia la base.
  final List<LatLng> path;

  /// Índice del tramo actual (`path[segment] → path[segment+1]`).
  int segment;

  /// Fracción recorrida dentro del tramo actual (0..1).
  double tInSegment;

  /// Posición interpolada actual.
  LatLng position;

  bool get reachedEnd => segment >= path.length - 1;
}
