import 'package:latlong2/latlong.dart';

import '../secrets.dart' as secrets;

/// Constantes de la app: ubicación inicial, parámetros del mapa e identidad de
/// paquete. Único lugar donde vive la key/estilo de MapTiler.
class AppConfig {
  AppConfig._();

  /// Centro inicial del mapa: Palermo Soho, Buenos Aires.
  static const LatLng initialCenter = LatLng(-34.5889, -58.4306);
  static const double initialZoom = 17;
  static const double minZoom = 3;
  static const double maxZoom = 20;

  // --- MapTiler ---
  static const String mapStyle = 'streets-v2-dark';
  static const String maptilerKey = secrets.maptilerKey;
  static const String userAgentPackageName = 'com.example.map_spike';

  /// URL template de los tiles raster de MapTiler.
  static String get tileUrlTemplate =>
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=$maptilerKey';
}
