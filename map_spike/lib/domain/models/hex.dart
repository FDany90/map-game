import 'package:latlong2/latlong.dart';

/// Un hexágono del territorio: su id, su centro y los 6 vértices del polígono.
///
/// Modelo de dominio puro (sin dependencias de UI ni de red).
class Hex {
  const Hex({
    required this.id,
    required this.center,
    required this.vertices,
  });

  final int id;
  final LatLng center;
  final List<LatLng> vertices;
}
