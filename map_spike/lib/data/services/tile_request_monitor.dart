import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path_provider/path_provider.dart';

/// Cuenta los **requests de tiles que SÍ pegan a la red** (los facturables por
/// MapTiler). No cuenta los aciertos de caché: cuando un tile sale del disco, el
/// `DioCacheInterceptor` corta antes del `httpClientAdapter`, así que el contador
/// nunca se incrementa para un hit → este número coincide con el dashboard.
///
/// Acumula el total **por fecha en UTC** y lo persiste en disco, así que el total
/// del día **sobrevive a los reinicios** (`flutter run` / hot restart). Se bucketea
/// en UTC —no en hora local— porque el dashboard de MapTiler corta el día en UTC;
/// así el "hoy" del chip es comparable directo con Analytics (ver doc 08).
///
/// Herramienta de **diagnóstico/medición** (ADR 0005 / doc 08).
class TileRequestMonitor extends ChangeNotifier {
  int _session = 0; // requests desde el último reset (= "esta prueba")
  final Map<int, int> _byZoom = {}; // por zoom, de esta prueba
  final Map<String, int> _byDate = {}; // fecha UTC (yyyy-MM-dd) -> requests acumulados

  File? _file;
  Timer? _saveTimer;

  int get session => _session;

  /// Total acumulado del día **en curso (UTC)**, persistido entre reinicios.
  /// Este es el número a comparar contra la barra del día en el dashboard.
  int get todayTotal => _byDate[_todayKey] ?? 0;

  Map<int, int> get byZoom => Map.unmodifiable(_byZoom);
  Map<String, int> get byDate => Map.unmodifiable(_byDate);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _todayKey => _fmt(DateTime.now().toUtc());

  /// Carga el acumulado por fecha desde disco. Llamar una vez en `main()` después
  /// de `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/tile_requests_by_date.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String && v is int) _byDate[k] = v;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[tiles] no se pudo cargar el log por fecha: $e');
    }
    notifyListeners();
  }

  void record(int? zoom) {
    _session++;
    _byDate[_todayKey] = todayTotal + 1;
    if (zoom != null) _byZoom[zoom] = (_byZoom[zoom] ?? 0) + 1;
    if (kDebugMode) {
      debugPrint(
          '[tiles] MISS z$zoom  ·  prueba=$_session  hoy(UTC)=$todayTotal');
    }
    _scheduleSave();
    notifyListeners();
  }

  /// Cierra la prueba: imprime el resumen (log por prueba) y pone el contador de
  /// **sesión** en 0. El acumulado por fecha (persistido) NO se toca.
  void reset() {
    if (kDebugMode) {
      debugPrint('[tiles] ===== fin de prueba: $_session requests '
          '(hoy UTC acumulado: $todayTotal) =====');
      final sorted = _byZoom.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        debugPrint('[tiles]   z${e.key}: ${e.value}');
      }
    }
    _session = 0;
    _byZoom.clear();
    _flush(); // persistir ya, sin esperar el debounce
    notifyListeners();
  }

  void _scheduleSave() {
    // Coalesce sin resetear: la 1ª llamada arma el timer; las siguientes NO lo
    // reinician (si no, una ráfaga continua de tiles posterga la escritura para
    // siempre). `_byDate` se escribe vivo, así que siempre guarda lo último.
    _saveTimer ??= Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      _flush();
    });
  }

  Future<void> _flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(_byDate));
    } catch (e) {
      if (kDebugMode) debugPrint('[tiles] no se pudo guardar el log por fecha: $e');
    }
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
