import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/streets_repository.dart';
import '../../../../data/services/overpass_service.dart';
import '../../../../domain/models/streets_source.dart';
import '../view_models/zombie_spike_view_model.dart';

/// Spike L0: zombies caminando por las calles hacia la base, muertos por la
/// torreta. Representación VISUAL del farmeo (ver `docs/11-zombies-calles-cost.md`).
///
/// Primer paso con `MarkerLayer` de flutter_map para validar el visual y medir
/// runtime; el paso a Flame queda para cuando suba el conteo/animación.
class ZombieSpikeScreen extends StatefulWidget {
  const ZombieSpikeScreen({super.key, required this.tileStore});

  final CacheStore tileStore;

  @override
  State<ZombieSpikeScreen> createState() => _ZombieSpikeScreenState();
}

class _ZombieSpikeScreenState extends State<ZombieSpikeScreen> {
  late final ZombieSpikeViewModel _viewModel = ZombieSpikeViewModel(
    streetsRepository: StreetsRepository(overpass: OverpassService()),
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike: zombies por las calles'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.loading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Cargando calles (Overpass)…'),
                ],
              ),
            );
          }
          return Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: AppConfig.initialCenter,
                  initialZoom: 16,
                  minZoom: AppConfig.minZoom,
                  maxZoom: AppConfig.maxZoom,
                  interactionOptions:
                      InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.tileUrlTemplate,
                    userAgentPackageName: AppConfig.userAgentPackageName,
                    tileProvider: CachedTileProvider(
                      maxStale: const Duration(days: 30),
                      store: widget.tileStore,
                    ),
                  ),
                  // Calles cargadas (los "carriles" por donde caminan).
                  PolylineLayer(
                    polylines: [
                      for (final street in _viewModel.streets)
                        Polyline(
                          points: street,
                          color: Colors.cyanAccent.withValues(alpha: 0.25),
                          strokeWidth: 2,
                        ),
                    ],
                  ),
                  // Rango de la torreta.
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _viewModel.base,
                        radius: _viewModel.turretRange,
                        useRadiusInMeter: true,
                        color: Colors.redAccent.withValues(alpha: 0.06),
                        borderColor: Colors.redAccent.withValues(alpha: 0.5),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                  // Disparos (efímeros).
                  PolylineLayer(
                    polylines: [
                      for (final shot in _viewModel.shots)
                        Polyline(
                          points: [shot.from, shot.to],
                          color: Colors.yellowAccent,
                          strokeWidth: 2,
                        ),
                    ],
                  ),
                  // Zombies + base.
                  MarkerLayer(
                    markers: [
                      for (final z in _viewModel.zombies)
                        Marker(
                          point: z.position,
                          width: 24,
                          height: 24,
                          child: const Icon(Icons.pest_control,
                              color: Colors.greenAccent, size: 22),
                        ),
                      Marker(
                        point: _viewModel.base,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.security,
                            color: Colors.redAccent, size: 30),
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
              Positioned(top: 0, left: 0, right: 0, child: _hud()),
            ],
          );
        },
      ),
    );
  }

  Widget _hud() {
    return IgnorePointer(
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stat('Eliminados', '${_viewModel.kills}'),
                  _stat('Activos', '${_viewModel.activeCount}'),
                  _stat('Recursos', '+${_viewModel.supplies}'),
                  _stat('Fugados', '${_viewModel.breaches}'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Calles: ${_sourceLabel(_viewModel.source)}'
                ' · la torreta dispara dentro del círculo rojo.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(StreetsSource source) => switch (source) {
        StreetsSource.overpass => 'Overpass (OSM real)',
        StreetsSource.cache => 'caché local (OSM)',
        StreetsSource.fallback => 'fallback sintético',
      };

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
