import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/territory_repository.dart';
import '../../../../data/services/hex_grid_service.dart';
import '../../../../data/services/save_store.dart';
import '../../../../data/services/threat_service.dart';
import '../../../../data/services/tile_request_monitor.dart';
import '../../../../domain/models/build_result.dart';
import '../../../../domain/models/claim_result.dart';
import '../../../../domain/models/map_marker.dart';
import '../../../../domain/models/outpost.dart';
import '../../../../domain/models/scene_template.dart';
import '../../../widgets/tile_request_badge.dart';
import '../../combat_scene/views/combat_play_screen.dart';
import '../../combat_scene/views/iso_template_preview_screen.dart';
import '../../osm_inspector/views/osm_inspector_screen.dart';
import '../../zombies/views/zombie_spike_screen.dart';
import '../view_models/map_view_model.dart';
import 'widgets/economy_hud.dart';
import 'widgets/outpost_widgets.dart';
import 'widgets/threat_widgets.dart';

/// Modo de colocación activo: cuando no es [none], el próximo toque en el mapa
/// ubica algo (mi posición / campamento) en vez de reclamar un hexágono.
enum _PlaceMode { none, moveLocation, placeCamp }

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
    this.saveStore,
  });

  final CacheStore tileStore;
  final HexGridService gridService;
  final TerritoryRepository territory;
  final SaveStore? saveStore;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  late final MapViewModel _viewModel = MapViewModel(
    gridService: widget.gridService,
    territory: widget.territory,
    threatService: ThreatService(spawn: AppConfig.initialCenter),
    saveStore: widget.saveStore,
  );

  _PlaceMode _placeMode = _PlaceMode.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guardar YA cuando la app pasa a segundo plano / se cierra: no perder el
    // avance ganado entre guardados debounced (doc 22).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _viewModel.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.saveNow();
    _viewModel.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  void _onTapMap(LatLng point) {
    switch (_placeMode) {
      case _PlaceMode.moveLocation:
        _viewModel.movePlayerTo(point);
        setState(() => _placeMode = _PlaceMode.none);
        _snack('📍 Te moviste acá');
        return;
      case _PlaceMode.placeCamp:
        final r = _viewModel.placeCamp(point);
        setState(() => _placeMode = _PlaceMode.none);
        _snack(r == BuildResult.success ? '⛺ Campamento listo' : r.error!);
        return;
      case _PlaceMode.none:
        final result = _viewModel.claimNearest(point);
        if (result == ClaimResult.notEnoughSupplies) {
          _snack('No tenés suficientes suministros (cuesta 10)');
        }
    }
  }

  /// Abre el menú de construcción (campamento / base / mover ubicación).
  void _openBuildMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1F26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => BuildMenuSheet(
        hasCamp: _viewModel.camp != null,
        hasBase: _viewModel.hasBase,
        campCost: _viewModel.campCost,
        baseCost: _viewModel.baseCost,
        canAffordCamp: _viewModel.canAffordCamp,
        canAffordBase: _viewModel.canAffordBase,
        onMoveLocation: () {
          Navigator.of(sheetCtx).pop();
          setState(() => _placeMode = _PlaceMode.moveLocation);
        },
        onPlaceCamp: () {
          Navigator.of(sheetCtx).pop();
          setState(() => _placeMode = _PlaceMode.placeCamp);
        },
        onFoundBase: () {
          Navigator.of(sheetCtx).pop();
          _confirmFoundBase();
        },
      ),
    );
  }

  /// Confirmación **fuerte** antes de fundar la base (es permanente y mover
  /// después es costoso). Se funda en la posición actual del jugador.
  Future<void> _confirmFoundBase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F26),
        title: const Text('¿Fundar tu base acá?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Tu base es PERMANENTE y se ancla a esta cuadra (tu posición actual).\n\n'
          'Elegí bien: mover una base después es muy costoso. Conviene fundarla '
          'donde vivís o jugás la mayor parte del tiempo.\n\n'
          'Costo: ${_viewModel.baseCost.round()} suministros.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF46C66B)),
            child: const Text('Fundar acá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = _viewModel.foundBaseAtPlayer();
    if (r == BuildResult.success) {
      _snack('🛡️ Base fundada. ¡Tu territorio!');
    } else {
      _snack(r.error ?? 'No se pudo fundar la base');
    }
  }

  /// Abre el popup (bottom sheet) de una amenaza; "Atacar" carga la escena de
  /// combate (por ahora el template default; la dificultad manejará el combate en
  /// una próxima iteración — `CombatConfig`).
  void _showThreatSheet(MapMarker marker) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1F26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => ThreatDetailSheet(
        marker: marker,
        canAttack: _viewModel.canAttack(marker),
        distanceMeters: _viewModel.distanceToNearestAnchor(marker),
        onAttack: () {
          Navigator.of(sheetCtx).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CombatPlayScreen(template: SceneTemplates.all.first),
            ),
          );
        },
      ),
    );
  }

  void _changeZoom(double delta) {
    final z = (_viewModel.zoom + delta)
        .clamp(AppConfig.minZoom, AppConfig.maxZoom)
        .toDouble();
    _mapController.move(_mapController.camera.center, z);
  }

  /// Salta a un **nivel de zoom predefinido** (banda LOD, ver doc 08/13): en vez
  /// de zoom libre, el jugador alterna entre Ciudad / Barrio / Base.
  void _setZoom(double z) {
    _mapController.move(
      _mapController.camera.center,
      z.clamp(AppConfig.minZoom, AppConfig.maxZoom).toDouble(),
    );
  }

  /// Vuelve al centro inicial (la "base") sin cambiar el zoom.
  void _recenter() =>
      _mapController.move(AppConfig.initialCenter, _viewModel.zoom);

  /// Barra de **bandas de zoom** (LOD): salta directo a Ciudad/Barrio/Base con
  /// `move()` (instantáneo → no carga tiles intermedios) + recenter a la base.
  Widget _zoomBar() {
    final z = _viewModel.zoom.round();

    Widget tile(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
      return Material(
        color: active ? Colors.cyan.shade700 : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ],
            ),
          ),
        ),
      );
    }

    Widget band(IconData icon, String label, int zoom) => tile(
          icon,
          label,
          active: (z - zoom).abs() <= 1,
          onTap: () => _setZoom(zoom.toDouble()),
        );

    return Wrap(
      spacing: 6,
      children: [
        band(Icons.location_city, 'Ciudad', 10),
        band(Icons.holiday_village, 'Barrio', 14),
        band(Icons.home, 'Base', 18),
        tile(Icons.my_location, 'Centro', onTap: _recenter),
      ],
    );
  }

  /// Chip de estado: indica la progresión sin base → campamento → base.
  Widget _statusPill() {
    final (icon, text, color) = switch ((_viewModel.hasBase, _viewModel.camp)) {
      (true, _) => ('🛡️', 'Base', const Color(0xFF46C66B)),
      (false, != null) => ('⛺', 'Campamento', const Color(0xFFE5B53D)),
      _ => ('🧍', 'Sin base', Colors.white54),
    };
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Banner del modo colocación: dice qué tocar y permite cancelar.
  Widget _placeBanner() {
    final text = _placeMode == _PlaceMode.moveLocation
        ? '📍 Tocá el mapa para moverte ahí'
        : '⛺ Tocá el mapa para ubicar el campamento';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7DEB).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _placeMode = _PlaceMode.none),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
                  // Solo PAN (arrastrar). El zoom continuo (pinch/doble-tap/
                  // scroll) está DESACTIVADO a propósito: el zoom cambia solo con
                  // los botones de banda → saltos instantáneos sin cargar tiles
                  // intermedios (control de costo, doc 08).
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.flingAnimation |
                        InteractiveFlag.pinchMove,
                  ),
                  onTap: (_, point) => _onTapMap(point),
                  onPositionChanged: (camera, _) =>
                      _viewModel.onCameraChanged(camera.center, camera.zoom),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.tileUrlTemplate,
                    userAgentPackageName: AppConfig.userAgentPackageName,
                    tileSize: AppConfig.tileSize, // 512 nativo: ~⅓ requests (doc 08)
                    zoomOffset: AppConfig.tileZoomOffset,
                    // Caché 30 días + contador de requests facturables.
                    tileProvider: buildCountingTileProvider(widget.tileStore),
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
                  // Radio de ataque alrededor de cada anclaje (posición/camp/
                  // base): hace VISIBLE dónde se puede atacar (skill UI: diegético
                  // en el mapa, no en un cartel).
                  CircleLayer(
                    circles: [
                      for (final a in _viewModel.attackAnchors)
                        CircleMarker(
                          point: a,
                          radius: MapViewModel.attackRadiusMeters,
                          useRadiusInMeter: true,
                          color: Colors.cyanAccent.withValues(alpha: 0.06),
                          borderColor: Colors.cyanAccent.withValues(alpha: 0.35),
                          borderStrokeWidth: 1.5,
                        ),
                    ],
                  ),
                  // Amenazas (grupos de zombies, etc.) — iconos tappables.
                  MarkerLayer(
                    markers: [
                      for (final m in _viewModel.threats)
                        Marker(
                          point: m.position,
                          width: 48,
                          height: 60,
                          alignment: Alignment.topCenter,
                          child: ThreatMarker(
                            marker: m,
                            onTap: () => _showThreatSheet(m),
                          ),
                        ),
                    ],
                  ),
                  // Asentamientos + posición del jugador (encima de las amenazas).
                  MarkerLayer(
                    markers: [
                      if (_viewModel.camp != null)
                        Marker(
                          point: _viewModel.camp!.position,
                          width: 72,
                          height: 72,
                          alignment: Alignment.topCenter,
                          child: const OutpostMarker(kind: OutpostKind.camp),
                        ),
                      if (_viewModel.base != null)
                        Marker(
                          point: _viewModel.base!.position,
                          width: 72,
                          height: 72,
                          alignment: Alignment.topCenter,
                          child: const OutpostMarker(kind: OutpostKind.base),
                        ),
                      Marker(
                        point: _viewModel.playerPosition,
                        width: 30,
                        height: 30,
                        child: const PlayerLocationMarker(),
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
              // Chip de estado del asentamiento (sin base / campamento / base).
              Positioned(
                top: 0,
                right: 8,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 70),
                    child: _statusPill(),
                  ),
                ),
              ),
              // Banner de modo colocación: instrucción + cancelar.
              if (_placeMode != _PlaceMode.none)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(child: Center(child: _placeBanner())),
                ),
              const Positioned(
                left: 8,
                bottom: 8,
                child: SafeArea(child: TileRequestBadge()),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: SafeArea(child: Center(child: _zoomBar())),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'build',
            backgroundColor: Colors.teal.shade600,
            onPressed: _openBuildMenu,
            icon: const Icon(Icons.construction),
            label: const Text('Construir'),
          ),
          const SizedBox(height: 8),
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
            heroTag: 'iso',
            mini: true,
            backgroundColor: Colors.purple.shade600,
            // ADR 0007 Rev 3: preview del template de escena en isométrico 2.5D
            // con cajas placeholder (no necesita OSM).
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IsoTemplatePreviewScreen(),
              ),
            ),
            child: const Icon(Icons.view_in_ar),
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
            // Guarda SINCRÓNICO antes de cerrar: `pop()` finaliza la actividad al
            // instante y un write async no llegaría a completar (doc 22).
            onPressed: () {
              _viewModel.saveNow();
              SystemNavigator.pop();
            },
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
