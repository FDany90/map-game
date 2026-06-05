import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/territory_repository.dart';
import '../../../../data/services/hex_grid_service.dart';
import '../../../../data/services/threat_service.dart';
import '../../../../domain/models/claim_result.dart';
import '../../../../domain/models/hex.dart';
import '../../../../domain/models/map_marker.dart';

/// Estado y lógica de presentación de la pantalla del mapa (MVVM).
///
/// Mantiene la grilla, corre el tick económico y delega el estado de juego en
/// [TerritoryRepository]. Expone snapshots inmutables a la View.
class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required HexGridService gridService,
    required TerritoryRepository territory,
    required ThreatService threatService,
    double initialZoom = AppConfig.initialZoom,
  })  : _gridService = gridService, // ignore: prefer_initializing_formals
        _territory = territory, // ignore: prefer_initializing_formals
        _threatService = threatService, // ignore: prefer_initializing_formals
        _zoom = initialZoom {
    _hexes = _gridService.generateGrid();
    _threatCenter = AppConfig.initialCenter;
    _threats = _threatService.threatsAround(_threatCenter);
    // Tick económico 4 veces por segundo (suficiente para un contador en vivo).
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_territory.claimedCount == 0) return;
      _territory.produce(0.25);
      notifyListeners();
    });
  }

  final HexGridService _gridService;
  final TerritoryRepository _territory;
  final ThreatService _threatService;
  late final List<Hex> _hexes;
  late List<MapMarker> _threats;
  late LatLng _threatCenter;
  Timer? _ticker;
  double _zoom;

  // --- Snapshots inmutables para la View ---
  List<Hex> get hexes => List.unmodifiable(_hexes);
  double get supplies => _territory.supplies;
  int get claimedCount => _territory.claimedCount;
  double get productionPerMinute => _territory.productionPerSecond * 60;
  double get zoom => _zoom;
  bool isClaimed(int hexId) => _territory.isClaimed(hexId);

  /// Amenazas visibles (grupos de zombies, etc.). Deterministas por posición.
  List<MapMarker> get threats => List.unmodifiable(_threats);

  /// Intenta reclamar el hexágono más cercano a [point]. Devuelve el resultado
  /// para que la View muestre feedback, o `null` si el toque cayó fuera de la
  /// grilla (no-op).
  ClaimResult? claimNearest(LatLng point) {
    final hex = _gridService.nearestHexTo(point, _hexes);
    if (hex == null) return null;
    final result = _territory.claim(hex.id);
    if (result == ClaimResult.success) notifyListeners();
    return result;
  }

  /// Reinicia la economía al estado inicial.
  void reset() {
    _territory.reset();
    notifyListeners();
  }

  /// Actualiza el zoom del HUD y **regenera las amenazas** si la cámara se movió
  /// más de una celda (las amenazas son deterministas, así que recalcular es
  /// barato y estable: las mismas celdas dan las mismas amenazas).
  void onCameraChanged(LatLng center, double zoom) {
    var changed = false;
    if (zoom != _zoom) {
      _zoom = zoom;
      changed = true;
    }
    if ((center.latitude - _threatCenter.latitude).abs() > ThreatService.cellDeg ||
        (center.longitude - _threatCenter.longitude).abs() > ThreatService.cellDeg) {
      _threatCenter = center;
      _threats = _threatService.threatsAround(center);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
