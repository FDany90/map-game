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

  /// Cap de zoom: z18 alcanza para el Modo Base (cuadra). z19/z20 cuestan 4×/16×
  /// los tiles para el mismo detalle → se evitan (control de costo, doc 08).
  static const double maxZoom = 18;

  /// Tamaño de tile. **Experimento 512 revertido (2026-05-31):** en flutter_map 7
  /// `tileSize: 512` desplazaba el encuadre varios niveles (el mapa abría a escala
  /// país, no de barrio). Queda en 256 (default). El ahorro de requests por
  /// tile-grande hay que lograrlo con config de CRS/`zoomOffset`, a futuro. Doc 08.
  static const double tileSize = 256;

  // --- MapTiler ---
  static const String mapStyle = 'streets-v2-dark';
  static const String maptilerKey = secrets.maptilerKey;
  static const String userAgentPackageName = 'com.example.map_spike';

  /// URL template de los tiles raster de MapTiler.
  static String get tileUrlTemplate =>
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=$maptilerKey';
}
