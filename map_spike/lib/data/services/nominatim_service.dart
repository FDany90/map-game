import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Dirección aproximada de un punto (reverse geocoding).
class PlaceAddress {
  PlaceAddress({
    required this.display,
    this.road,
    this.houseNumber,
    this.suburb,
    this.city,
  });

  /// Texto completo listo para mostrar / buscar en Google Maps.
  final String display;
  final String? road; // calle
  final String? houseNumber; // altura
  final String? suburb; // barrio
  final String? city;

  /// "Calle 1234" si hay datos, si no la calle, si no el display.
  String get streetLine {
    if (road != null && houseNumber != null) return '$road $houseNumber';
    return road ?? display;
  }
}

/// Cliente de **Nominatim** (geocoder oficial de OSM): convierte lat/lon en una
/// dirección legible (calle + altura). Útil para ubicar el punto consultado y
/// cotejarlo en Google Maps. Servicio puro; la caché/llamada bajo demanda las
/// orquesta quien lo usa.
///
/// Fair-use de Nominatim: **User-Agent propio** obligatorio y **máx ~1 req/seg**
/// (no llamar por frame; solo al tocar un punto). Sin API key, gratis, sin SLA.
class NominatimService {
  NominatimService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _endpoint = 'https://nominatim.openstreetmap.org/reverse';
  static const String _userAgent =
      'map-game-spike/0.1 (https://github.com/FDany90/map-game)';

  /// Reverse geocoding de [point]. Devuelve `null` si no hay dirección o falla
  /// (no es crítico: es info de apoyo, no rompe la escena).
  Future<PlaceAddress?> reverse(LatLng point) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {
          'format': 'jsonv2',
          'lat': point.latitude,
          'lon': point.longitude,
          'zoom': 18, // nivel "edificio/calle"
          'addressdetails': 1,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: const {'User-Agent': _userAgent},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = resp.data;
      if (data == null) return null;
      final addr = (data['address'] as Map?) ?? const {};
      String? s(String k) => addr[k]?.toString();
      return PlaceAddress(
        display: (data['display_name'] ?? '').toString(),
        road: s('road') ?? s('pedestrian') ?? s('footway'),
        houseNumber: s('house_number'),
        suburb: s('suburb') ?? s('neighbourhood') ?? s('quarter'),
        city: s('city') ?? s('town') ?? s('village') ?? s('state'),
      );
    } catch (e) {
      debugPrint('NominatimService.reverse falló: $e');
      return null;
    }
  }
}
