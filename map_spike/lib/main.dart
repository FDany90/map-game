import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config/app_config.dart';
import 'data/repositories/territory_repository.dart';
import 'data/services/hex_grid_service.dart';
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

  // Capa de datos (hoy en memoria; seam para el backend en Etapa 6).
  const gridService = HexGridService(center: AppConfig.initialCenter);
  final territory = TerritoryRepository();

  runApp(
    MapSpikeApp(
      tileStore: tileStore,
      gridService: gridService,
      territory: territory,
    ),
  );
}

class MapSpikeApp extends StatelessWidget {
  const MapSpikeApp({
    super.key,
    required this.tileStore,
    required this.gridService,
    required this.territory,
  });

  final CacheStore tileStore;
  final HexGridService gridService;
  final TerritoryRepository territory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAP Spike',
      home: MapScreen(
        tileStore: tileStore,
        gridService: gridService,
        territory: territory,
      ),
    );
  }
}
