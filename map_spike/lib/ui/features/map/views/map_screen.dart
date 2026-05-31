import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/territory_repository.dart';
import '../../../../data/services/hex_grid_service.dart';
import '../../../../domain/models/claim_result.dart';
import '../../osm_inspector/views/osm_inspector_screen.dart';
import '../../zombies/views/zombie_spike_screen.dart';
import '../view_models/map_view_model.dart';
import 'widgets/economy_hud.dart';

/// Pantalla principal: mapa MapTiler + grilla de hexágonos + HUD de economía.
///
/// View del patrón MVVM: arma el [MapViewModel] con las dependencias inyectadas
/// y se limita a renderizar su estado (vía [ListenableBuilder]) y a delegarle
/// las interacciones.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.tileStore,
    required this.gridService,
    required this.territory,
  });

  final CacheStore tileStore;
  final HexGridService gridService;
  final TerritoryRepository territory;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final MapViewModel _viewModel = MapViewModel(
    gridService: widget.gridService,
    territory: widget.territory,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onTapMap(LatLng point) {
    final result = _viewModel.claimNearest(point);
    if (result == ClaimResult.notEnoughSupplies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tenés suficientes suministros (cuesta 10)'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _changeZoom(double delta) {
    final z = (_viewModel.zoom + delta)
        .clamp(AppConfig.minZoom, AppConfig.maxZoom)
        .toDouble();
    _mapController.move(_mapController.camera.center, z);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: AppConfig.initialCenter,
                  initialZoom: AppConfig.initialZoom,
                  minZoom: AppConfig.minZoom,
                  maxZoom: AppConfig.maxZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                    scrollWheelVelocity: 0.01,
                  ),
                  onTap: (_, point) => _onTapMap(point),
                  onPositionChanged: (camera, _) =>
                      _viewModel.onZoomChanged(camera.zoom),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.tileUrlTemplate,
                    userAgentPackageName: AppConfig.userAgentPackageName,
                    tileProvider: CachedTileProvider(
                      // Tiles válidos 30 días antes de re-pedirse a MapTiler.
                      maxStale: const Duration(days: 30),
                      store: widget.tileStore,
                    ),
                  ),
                  PolygonLayer(
                    polygons: [
                      for (final hex in _viewModel.hexes)
                        Polygon(
                          points: hex.vertices,
                          borderColor: Colors.cyanAccent.withValues(alpha: 0.4),
                          borderStrokeWidth: 1,
                          color: _viewModel.isClaimed(hex.id)
                              ? Colors.greenAccent.withValues(alpha: 0.45)
                              : Colors.cyanAccent.withValues(alpha: 0.04),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© MapTiler © OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: EconomyHud(
                  supplies: _viewModel.supplies,
                  claimedCount: _viewModel.claimedCount,
                  productionPerMinute: _viewModel.productionPerMinute,
                  zoom: _viewModel.zoom,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'zin',
            mini: true,
            onPressed: () => _changeZoom(1),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zout',
            mini: true,
            onPressed: () => _changeZoom(-1),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'reset',
            mini: true,
            onPressed: _viewModel.reset,
            child: const Icon(Icons.restart_alt),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zombies',
            mini: true,
            backgroundColor: Colors.green.shade700,
            // Spike L0: zombies caminando por las calles + torreta.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ZombieSpikeScreen(tileStore: widget.tileStore),
              ),
            ),
            child: const Icon(Icons.pest_control),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'osm',
            mini: true,
            backgroundColor: Colors.blue.shade700,
            // Fase 1 (ADR 0007): inspector de datos OSM crudos del punto.
            onPressed: () {
              // Abrir el inspector donde está mirando el mapa real: navegás a
              // otro lugar/país y lo inspeccionás ahí mismo (ADR 0007).
              final cam = _mapController.camera;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OsmInspectorScreen(
                    tileStore: widget.tileStore,
                    initialCenter: cam.center,
                    initialZoom: cam.zoom,
                  ),
                ),
              );
            },
            child: const Icon(Icons.travel_explore),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'close',
            mini: true,
            backgroundColor: Colors.red.shade700,
            // Cierra la app de forma prolija en Android (no usar exit(0)).
            onPressed: () => SystemNavigator.pop(),
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
