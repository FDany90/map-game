import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../domain/models/hex.dart';

/// Genera y consulta la grilla hexagonal sobre el mapa.
///
/// Servicio sin estado (data layer). La geometría es una aproximación plana,
/// suficiente a escala de un barrio; cuando el territorio sea global conviene
/// migrar a H3 (ver ADRs).
class HexGridService {
  const HexGridService({
    required this.center,
    this.hexRadiusMeters = 60,
    this.rings = 6,
  });

  /// Centro de la grilla (las coordenadas se calculan relativas a este punto).
  final LatLng center;

  /// Radio de cada hexágono en metros.
  final double hexRadiusMeters;

  /// Cantidad de anillos de hexágonos alrededor del centro.
  final int rings;

  static const double _metersPerDegLat = 111320;

  /// Genera la grilla completa de hexágonos alrededor de [center].
  List<Hex> generateGrid() {
    final hexes = <Hex>[];
    final r = hexRadiusMeters;
    final width = math.sqrt(3) * r;
    final height = 1.5 * r;
    var id = 0;
    for (var row = -rings; row <= rings; row++) {
      for (var col = -rings; col <= rings; col++) {
        final cx = width * (col + (row.isOdd ? 0.5 : 0.0));
        final cy = height * row;
        final hexCenter = _offsetMeters(cx, cy);
        final vertices = <LatLng>[
          for (var i = 0; i < 6; i++)
            _offsetMeters(
              cx + r * math.cos((60 * i - 30) * math.pi / 180),
              cy + r * math.sin((60 * i - 30) * math.pi / 180),
            ),
        ];
        hexes.add(Hex(id: id++, center: hexCenter, vertices: vertices));
      }
    }
    return hexes;
  }

  /// Hexágono de [hexes] más cercano a [point], o `null` si ninguno cae dentro
  /// del radio de un hexágono (toque fuera de la grilla).
  Hex? nearestHexTo(LatLng point, List<Hex> hexes) {
    Hex? nearest;
    var best = double.infinity;
    for (final h in hexes) {
      final d = _distanceMeters(h.center, point);
      if (d < best) {
        best = d;
        nearest = h;
      }
    }
    if (nearest == null || best > hexRadiusMeters) return null;
    return nearest;
  }

  LatLng _offsetMeters(double dx, double dy) {
    final dLat = dy / _metersPerDegLat;
    final dLon =
        dx / (_metersPerDegLat * math.cos(center.latitude * math.pi / 180));
    return LatLng(center.latitude + dLat, center.longitude + dLon);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    final dLat = (a.latitude - b.latitude) * _metersPerDegLat;
    final dLon = (a.longitude - b.longitude) *
        _metersPerDegLat *
        math.cos(center.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }
}
