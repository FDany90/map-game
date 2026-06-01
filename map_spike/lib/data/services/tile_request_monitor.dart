import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';

/// Cuenta los **requests de tiles que SÍ pegan a la red** (los facturables por
/// MapTiler). No cuenta los aciertos de caché: cuando un tile sale del disco, el
/// `DioCacheInterceptor` corta antes del `httpClientAdapter`, así que el contador
/// nunca se incrementa para un hit → este número coincide con el dashboard.
///
/// Herramienta de **diagnóstico/medición** (ADR 0005 / doc 08): permite ver, por
/// prueba, cuántos requests se gastaron y en qué niveles de zoom.
class TileRequestMonitor extends ChangeNotifier {
  int _session = 0; // requests desde el último reset (= "esta prueba")
  int _total = 0; // requests desde que arrancó la app
  final Map<int, int> _byZoom = {};

  int get session => _session;
  int get total => _total;
  Map<int, int> get byZoom => Map.unmodifiable(_byZoom);

  void record(int? zoom) {
    _session++;
    _total++;
    if (zoom != null) _byZoom[zoom] = (_byZoom[zoom] ?? 0) + 1;
    if (kDebugMode) {
      debugPrint('[tiles] MISS z$zoom  ·  prueba=$_session  total=$_total');
    }
    notifyListeners();
  }

  /// Cierra la prueba: imprime el resumen (log por prueba que pediste) y pone el
  /// contador de sesión en 0. El total acumulado se mantiene.
  void reset() {
    if (kDebugMode) {
      debugPrint('[tiles] ===== fin de prueba: $_session requests =====');
      final sorted = _byZoom.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        debugPrint('[tiles]   z${e.key}: ${e.value}');
      }
    }
    _session = 0;
    _byZoom.clear();
    notifyListeners();
  }
}

/// Instancia global (herramienta de dev; evita cablear por constructor en 4 vistas).
final tileRequestMonitor = TileRequestMonitor();

/// `HttpClientAdapter` que cuenta cada fetch real y delega en el adapter interno.
class _CountingHttpClientAdapter implements HttpClientAdapter {
  _CountingHttpClientAdapter(this._inner);

  final HttpClientAdapter _inner;
  static final RegExp _zxy = RegExp(r'/(\d+)/(\d+)/(\d+)(?:@2x)?\.png');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final m = _zxy.firstMatch(options.uri.path);
    tileRequestMonitor.record(m == null ? null : int.tryParse(m.group(1)!));
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

/// Crea un [CachedTileProvider] con el contador enchufado. Reemplaza a construir
/// `CachedTileProvider(store:..., maxStale:...)` a mano en cada pantalla.
CachedTileProvider buildCountingTileProvider(CacheStore store) {
  final dio = Dio()..httpClientAdapter = _CountingHttpClientAdapter(IOHttpClientAdapter());
  return CachedTileProvider(
    dio: dio,
    store: store,
    maxStale: const Duration(days: 30),
  );
}
