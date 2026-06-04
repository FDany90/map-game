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

  /// Tamaño de tile. **MapTiler entrega los tiles en 512px nativo** (el SKU se
  /// factura como "Rendered maps (512px)"). Declararlos como 512 (en vez de 256)
  /// hace que cada request **cubra 4× el área** → ~⅓ de los requests para la misma
  /// vista (doc 08, palanca #2 tras la caché) **y** las etiquetas se ven al tamaño
  /// default (antes se achicaban al downscalear 512→256).
  ///
  /// Va de la mano de [tileZoomOffset]: sin él, flutter_map pide el z/x/y de un
  /// esquema 256 y el mapa abre desplazado (el bug del intento del 2026-05-31).
  static const double tileSize = 512;

  /// Compensa el esquema 512 de MapTiler: con tiles de 512 nativo, el z visible
  /// corresponde a `z-1` en el esquema 256 que asume flutter_map. Verificar el
  /// encuadre en emulador; si queda corrido un nivel, este es el knob.
  static const double tileZoomOffset = -1;

  // --- MapTiler ---
  static const String mapStyle = 'streets-v2-dark';
  static const String maptilerKey = secrets.maptilerKey;
  static const String userAgentPackageName = 'com.example.map_spike';

  /// URL template de los tiles raster de MapTiler.
  static String get tileUrlTemplate =>
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=$maptilerKey';
}
