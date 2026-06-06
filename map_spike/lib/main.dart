import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config/app_config.dart';
import 'data/repositories/territory_repository.dart';
import 'data/services/hex_grid_service.dart';
import 'data/services/save_store.dart';
import 'data/services/tile_request_monitor.dart';
import 'ui/features/map/views/map_screen.dart';

/// Composition root: arma las dependencias (caché de tiles, servicios,
/// repositorio) y las inyecta en la app por constructor.
///
/// Si la app crece, este cableado manual se reemplaza por un contenedor de DI
/// (`get_it` / `provider`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Caché de tiles en disco: persiste entre reinicios. Cada tile servido desde
  // acá = 1 request de MapTiler ahorrado.
  final dir = await getTemporaryDirectory();
  final tileStore = HiveCacheStore('${dir.path}/maptiler_tiles');

  // Carga el acumulado de requests por fecha (UTC) para que el total del día
  // sobreviva a los reinicios y sea comparable con el dashboard de MapTiler.
  await tileRequestMonitor.init();

  // Capa de datos (hoy en memoria + save local; seam para el backend en Etapa 6).
  const gridService = HexGridService(center: AppConfig.initialCenter);
  final territory = TerritoryRepository();

  // Carga el save del jugador y aplica el catch-up offline acotado (doc 22): así
  // cada corrida arranca con el avance acumulado, no de cero.
  final saveStore = SaveStore();
  final save = await saveStore.load();
  if (save != null) {
    territory.restore(save);
    territory.applyOfflineCatchUp(save.lastSeenEpochMs);
  }

  runApp(
    MapSpikeApp(
      tileStore: tileStore,
      gridService: gridService,
      territory: territory,
      saveStore: saveStore,
    ),
  );
}

class MapSpikeApp extends StatelessWidget {
  const MapSpikeApp({
    super.key,
    required this.tileStore,
    required this.gridService,
    required this.territory,
    this.saveStore,
  });

  final CacheStore tileStore;
  final HexGridService gridService;
  final TerritoryRepository territory;
  final SaveStore? saveStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAP Spike',
      home: MapScreen(
        tileStore: tileStore,
        gridService: gridService,
        territory: territory,
        saveStore: saveStore,
      ),
    );
  }
}
