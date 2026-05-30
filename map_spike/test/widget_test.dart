// Smoke test del spike.
//
// No montamos el FlutterMap en un widget test: al renderizarse dispara fetches
// de tiles (timers async vía dio) + el Timer.periodic de la economía, que quedan
// "pending" y hacen fallar el test sin aportar señal. La verificación real del
// mapa + caché se hace corriendo la app en el emulador.
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:map_spike/main.dart';

void main() {
  test('MapSpikeApp acepta un cache store de tiles', () {
    final app = MapSpikeApp(tileStore: MemCacheStore());
    expect(app.tileStore, isA<CacheStore>());
  });
}
