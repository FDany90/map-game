import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/osm_scene_repository.dart';
import '../../../../data/services/overpass_service.dart';
import '../../../../domain/models/osm_feature.dart';
import '../../../../domain/models/osm_scene.dart';
import '../../../../domain/models/streets_source.dart';
import '../view_models/osm_inspector_view_model.dart';

/// Inspector OSM interactivo (Fase 1, ADR 0007): **tocás un punto en el mapa** y
/// se consulta + dibuja la escena cruda de OSM en tiempo real (calles + edificios
/// + áreas resaltados sobre el mapa real), con conteos y cobertura de tags.
/// Base para diseñar la generación de la escena isométrica 2.5D.
class OsmInspectorScreen extends StatefulWidget {
  const OsmInspectorScreen({
    super.key,
    required this.tileStore,
    this.initialCenter,
    this.initialZoom = 17,
  });

  final CacheStore tileStore;

  /// Punto donde abrir (por defecto el del mapa principal): así "la primera vez
  /// se genera según dónde estoy" navegando el mapa real (ADR 0007).
  final LatLng? initialCenter;
  final double initialZoom;

  @override
  State<OsmInspectorScreen> createState() => _OsmInspectorScreenState();
}

class _OsmInspectorScreenState extends State<OsmInspectorScreen> {
  late final OsmInspectorViewModel _viewModel = OsmInspectorViewModel(
    repository: OsmSceneRepository(overpass: OverpassService()),
    initialCenter: widget.initialCenter,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        title: const Text('Inspector OSM'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _viewModel.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              // Mapa interactivo: tocar = consultar ese punto.
              Expanded(flex: 5, child: _map()),
              // Panel de datos del punto consultado.
              Expanded(flex: 4, child: _panel()),
            ],
          );
        },
      ),
    );
  }

  // --- Mapa interactivo con overlay de la escena consultada ---

  Widget _map() {
    final scene = _viewModel.scene;
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _viewModel.center,
            initialZoom: widget.initialZoom,
            minZoom: AppConfig.minZoom,
            maxZoom: AppConfig.maxZoom,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
            onTap: (_, point) => _viewModel.setCenter(point),
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
            // Áreas (leisure): polígonos verdes.
            if (scene != null)
              PolygonLayer(
                polygons: [
                  for (final f in scene.areas)
                    Polygon(
                      points: f.geometry,
                      color: Colors.greenAccent.withValues(alpha: 0.18),
                      borderColor: Colors.greenAccent.withValues(alpha: 0.6),
                      borderStrokeWidth: 1,
                    ),
                ],
              ),
            // Edificios: footprints naranjas.
            if (scene != null)
              PolygonLayer(
                polygons: [
                  for (final f in scene.buildings)
                    Polygon(
                      points: f.geometry,
                      color: Colors.orangeAccent.withValues(alpha: 0.35),
                      borderColor: Colors.orangeAccent,
                      borderStrokeWidth: 1.5,
                    ),
                ],
              ),
            // Calles: polylines resaltadas según tipo.
            if (scene != null)
              PolylineLayer(
                polylines: [
                  for (final f in scene.streets)
                    Polyline(
                      points: f.geometry,
                      color: _streetColor(f.tags['highway'] ?? ''),
                      strokeWidth: _streetWidth(f.tags['highway'] ?? ''),
                    ),
                ],
              ),
            // Radio consultado.
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _viewModel.center,
                  radius: _viewModel.radiusMeters,
                  useRadiusInMeter: true,
                  color: Colors.redAccent.withValues(alpha: 0.05),
                  borderColor: Colors.redAccent.withValues(alpha: 0.6),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
            // Punto consultado.
            MarkerLayer(
              markers: [
                Marker(
                  point: _viewModel.center,
                  width: 26,
                  height: 26,
                  child: const Icon(Icons.place,
                      color: Colors.redAccent, size: 26),
                ),
              ],
            ),
          ],
        ),
        // Chips de radio (arriba).
        Positioned(top: 8, left: 8, child: _radiusChips()),
        // Hint + loading.
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: _mapHint(),
        ),
      ],
    );
  }

  Widget _radiusChips() {
    return Wrap(
      spacing: 6,
      children: [
        for (final r in OsmInspectorViewModel.radiusOptions)
          GestureDetector(
            onTap: () => _viewModel.setRadius(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _viewModel.radiusMeters == r
                    ? Colors.redAccent
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text('${r.round()} m',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _mapHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (_viewModel.loading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            const Text('Consultando OSM…',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ] else
            const Expanded(
              child: Text('Tocá cualquier punto del mapa para inspeccionarlo.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- Panel de datos abajo ---

  Widget _panel() {
    final error = _viewModel.error;
    if (error != null) {
      return _ErrorView(message: error, onRetry: _viewModel.reload);
    }
    final scene = _viewModel.scene;
    if (scene == null) {
      return const Center(
        child: Text('Sin datos', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _summaryCard(scene),
        const SizedBox(height: 10),
        _streetsCard(scene),
        const SizedBox(height: 10),
        _buildingsCard(scene),
        const SizedBox(height: 10),
        _areasCard(scene),
      ],
    );
  }

  Widget _summaryCard(OsmScene scene) {
    final src = switch (scene.source) {
      StreetsSource.overpass => 'Overpass (OSM en vivo)',
      StreetsSource.cache => 'caché local (OSM)',
      StreetsSource.fallback => 'fallback',
    };
    return _card('Punto consultado', [
      Text(
        '${scene.center.latitude.toStringAsFixed(5)}, '
        '${scene.center.longitude.toStringAsFixed(5)}  ·  '
        'radio ${scene.radiusMeters.round()} m',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          _chip('${scene.streets.length} calles', Colors.lightBlueAccent),
          _chip('${scene.buildings.length} edificios', Colors.orangeAccent),
          _chip('${scene.areas.length} áreas', Colors.greenAccent),
        ],
      ),
      const SizedBox(height: 8),
      Text('Fuente: $src',
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }

  Widget _streetsCard(OsmScene scene) {
    final s = scene.streets;
    return _card('Calles (highway)', [
      _tallyLine('tipos', _viewModel.tally(s, 'highway')),
      const SizedBox(height: 6),
      _coverageLine(s, const ['name', 'lanes', 'oneway', 'surface', 'width']),
      _richest(s),
    ]);
  }

  Widget _buildingsCard(OsmScene scene) {
    final b = scene.buildings;
    return _card('Edificios (building)', [
      _tallyLine('tipos', _viewModel.tally(b, 'building')),
      const SizedBox(height: 6),
      _coverageLine(b,
          const ['building:levels', 'height', 'roof:shape', 'amenity', 'name']),
      _richest(b),
    ]);
  }

  Widget _areasCard(OsmScene scene) {
    final a = scene.areas;
    if (a.isEmpty) return const SizedBox.shrink();
    return _card('Áreas (leisure)', [
      _tallyLine('tipos', _viewModel.tally(a, 'leisure')),
      _richest(a),
    ]);
  }

  // --- helpers de UI ---

  Widget _tallyLine(String label, List<MapEntry<String, int>> entries) {
    final text = entries.isEmpty
        ? '—'
        : entries.take(8).map((e) => '${e.key}×${e.value}').join(' · ');
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54)),
          TextSpan(text: text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _coverageLine(List<OsmFeature> fs, List<String> keys) {
    final parts = [
      for (final k in keys) '$k ${_viewModel.coveragePct(fs, k)}%',
    ].join('  ·  ');
    return Text('cobertura: $parts',
        style: const TextStyle(color: Colors.white60, fontSize: 12));
  }

  Widget _richest(List<OsmFeature> fs) {
    final f = _viewModel.richest(fs);
    if (f == null || f.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
              'feature más rico (${f.tags.length} tags, ${f.geometry.length} pts)',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          children: [
            for (final e in f.tags.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.key,
                          style: const TextStyle(
                              color: Colors.cyanAccent, fontSize: 11)),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Color _streetColor(String type) {
    switch (type) {
      case 'motorway':
      case 'trunk':
      case 'primary':
        return Colors.amber;
      case 'secondary':
      case 'tertiary':
        return Colors.white;
      case 'footway':
      case 'path':
      case 'steps':
      case 'pedestrian':
      case 'cycleway':
        return Colors.cyanAccent.withValues(alpha: 0.7);
      default:
        return Colors.lightBlueAccent;
    }
  }

  double _streetWidth(String type) {
    switch (type) {
      case 'motorway':
      case 'trunk':
        return 7;
      case 'primary':
        return 6;
      case 'secondary':
        return 5;
      case 'tertiary':
        return 4;
      case 'footway':
      case 'path':
      case 'steps':
      case 'pedestrian':
      case 'cycleway':
        return 2;
      default:
        return 3.5;
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            const Text('No se pudo consultar Overpass',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
