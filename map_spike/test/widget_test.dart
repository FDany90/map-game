// Smoke test del spike.
//
// No montamos el FlutterMap en un widget test: al renderizarse dispara fetches
// de tiles (timers async vía dio) + el Timer.periodic de la economía, que quedan
// "pending" y hacen fallar el test sin aportar señal. La verificación real del
// mapa + caché se hace corriendo la app en el emulador.
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:map_spike/config/app_config.dart';
import 'package:map_spike/data/repositories/territory_repository.dart';
import 'package:map_spike/data/services/hex_grid_service.dart';
import 'package:map_spike/main.dart';

void main() {
  test('MapSpikeApp se arma con sus dependencias inyectadas', () {
    final app = MapSpikeApp(
      tileStore: MemCacheStore(),
      gridService: const HexGridService(center: AppConfig.initialCenter),
      territory: TerritoryRepository(),
    );
    expect(app.tileStore, isA<CacheStore>());
  });
}
