import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'secrets.dart' as secrets;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache de tiles en disco: persiste entre reinicios. Cada tile servido desde
  // aca = 1 request de MapTiler ahorrado.
  final dir = await getTemporaryDirectory();
  final tileStore = HiveCacheStore('${dir.path}/maptiler_tiles');
  runApp(MapSpikeApp(tileStore: tileStore));
}

class MapSpikeApp extends StatelessWidget {
  const MapSpikeApp({super.key, required this.tileStore});
  final CacheStore tileStore;
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'MAP Spike', home: MapScreen(tileStore: tileStore));
}

// Un hexágono del territorio.
class Hex {
  final int id;
  final LatLng center;
  final List<LatLng> vertices;
  const Hex(this.id, this.center, this.vertices);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.tileStore});
  final CacheStore tileStore;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String maptilerKey = secrets.maptilerKey;
  static const String style = 'streets-v2-dark';

  static const LatLng _centro = LatLng(-34.5889, -58.4306); // Palermo Soho
  static const double _zoomInicial = 17, _zoomMin = 3, _zoomMax = 20;
  static const double _hexRadioMetros = 60, _metrosPorGradoLat = 111320;
  static const int _anillos = 6;

  // --- Economía ---
  static const double _suministrosIniciales = 50;
  static const double _costoReclamar = 10;
  static const double _rendPorHexPorSeg = 0.5; // +0.5/seg por hex (= 30/min)

  final MapController _mapController = MapController();
  late final List<Hex> _hexes = _generarGrilla();
  final Set<int> _reclamados = {};
  double _suministros = _suministrosIniciales;
  double _zoom = _zoomInicial;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tick económico 4 veces por segundo (suficiente para un contador).
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_reclamados.isEmpty) return;
      setState(() => _suministros += _produccionPorSeg() * 0.25);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _produccionPorSeg() => _reclamados.length * _rendPorHexPorSeg;

  // --- geometría (grilla aprox. plana, suficiente para el demo local) ---
  LatLng _offsetMetros(double dx, double dy) {
    final dLat = dy / _metrosPorGradoLat;
    final dLon =
        dx / (_metrosPorGradoLat * math.cos(_centro.latitude * math.pi / 180));
    return LatLng(_centro.latitude + dLat, _centro.longitude + dLon);
  }

  double _distMetros(LatLng a, LatLng b) {
    final dLat = (a.latitude - b.latitude) * _metrosPorGradoLat;
    final dLon = (a.longitude - b.longitude) *
        _metrosPorGradoLat *
        math.cos(_centro.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  List<Hex> _generarGrilla() {
    final hexes = <Hex>[];
    const r = _hexRadioMetros;
    final ancho = math.sqrt(3) * r;
    const alto = 1.5 * r;
    int id = 0;
    for (int fila = -_anillos; fila <= _anillos; fila++) {
      for (int col = -_anillos; col <= _anillos; col++) {
        final cx = ancho * (col + (fila.isOdd ? 0.5 : 0.0));
        final cy = alto * fila;
        final center = _offsetMetros(cx, cy);
        final vertices = <LatLng>[
          for (int i = 0; i < 6; i++)
            _offsetMetros(
              cx + r * math.cos((60 * i - 30) * math.pi / 180),
              cy + r * math.sin((60 * i - 30) * math.pi / 180),
            ),
        ];
        hexes.add(Hex(id++, center, vertices));
      }
    }
    return hexes;
  }

  // --- interacción ---
  void _tocarHex(LatLng punto) {
    Hex? cerca;
    double mejor = double.infinity;
    for (final h in _hexes) {
      final d = _distMetros(h.center, punto);
      if (d < mejor) {
        mejor = d;
        cerca = h;
      }
    }
    if (cerca == null || mejor > _hexRadioMetros) return;
    final id = cerca.id;
    if (_reclamados.contains(id)) return; // ya es tuyo
    if (_suministros < _costoReclamar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tenés suficientes suministros (cuesta 10)'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    setState(() {
      _suministros -= _costoReclamar;
      _reclamados.add(id);
    });
  }

  void _reset() => setState(() {
        _reclamados.clear();
        _suministros = _suministrosIniciales;
      });

  void _cambiarZoom(double delta) {
    final z = (_zoom + delta).clamp(_zoomMin, _zoomMax).toDouble();
    _mapController.move(_mapController.camera.center, z);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: _zoomInicial,
              minZoom: _zoomMin,
              maxZoom: _zoomMax,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                scrollWheelVelocity: 0.01,
              ),
              onTap: (_, latLng) => _tocarHex(latLng),
              onPositionChanged: (cam, _) {
                if (cam.zoom != _zoom) setState(() => _zoom = cam.zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.png?key=$maptilerKey',
                userAgentPackageName: 'com.example.map_spike',
                tileProvider: CachedTileProvider(
                  // Tiles validos 30 dias antes de re-pedirse a MapTiler.
                  maxStale: const Duration(days: 30),
                  store: widget.tileStore,
                ),
              ),
              PolygonLayer(
                polygons: [
                  for (final h in _hexes)
                    Polygon(
                      points: h.vertices,
                      borderColor: Colors.cyanAccent.withValues(alpha: 0.4),
                      borderStrokeWidth: 1,
                      color: _reclamados.contains(h.id)
                          ? Colors.greenAccent.withValues(alpha: 0.45)
                          : Colors.cyanAccent.withValues(alpha: 0.04),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© MapTiler © OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          // HUD de economía arriba
          Positioned(top: 0, left: 0, right: 0, child: _hud()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'zin',
            mini: true,
            onPressed: () => _cambiarZoom(1),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zout',
            mini: true,
            onPressed: () => _cambiarZoom(-1),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'reset',
            mini: true,
            onPressed: _reset,
            child: const Icon(Icons.restart_alt),
          ),
        ],
      ),
    );
  }

  Widget _hud() {
    return SafeArea(
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
                _stat('Suministros', _suministros.toStringAsFixed(0)),
                _stat('Hexágonos', '${_reclamados.length}'),
                _stat('Producción',
                    '+${(_produccionPorSeg() * 60).toStringAsFixed(0)}/min'),
                _stat('Zoom', _zoom.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tocá un hexágono para reclamarlo (cuesta 10). Cada uno produce +30/min.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
