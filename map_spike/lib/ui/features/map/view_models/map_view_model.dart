import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/territory_repository.dart';
import '../../../../data/services/hex_grid_service.dart';
import '../../../../data/services/save_store.dart';
import '../../../../data/services/threat_service.dart';
import '../../../../domain/models/build_result.dart';
import '../../../../domain/models/claim_result.dart';
import '../../../../domain/models/hex.dart';
import '../../../../domain/models/map_marker.dart';
import '../../../../domain/models/outpost.dart';

/// Estado y lógica de presentación de la pantalla del mapa (MVVM).
///
/// Mantiene la grilla, corre el tick económico y delega el estado de juego en
/// [TerritoryRepository]. Expone snapshots inmutables a la View.
class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required HexGridService gridService,
    required TerritoryRepository territory,
    required ThreatService threatService,
    SaveStore? saveStore,
    double initialZoom = AppConfig.initialZoom,
  })  : _gridService = gridService, // ignore: prefer_initializing_formals
        _territory = territory, // ignore: prefer_initializing_formals
        _threatService = threatService, // ignore: prefer_initializing_formals
        _saveStore = saveStore, // ignore: prefer_initializing_formals
        _zoom = initialZoom {
    _hexes = _gridService.generateGrid();
    _threatCenter = AppConfig.initialCenter;
    _threats = _threatService.threatsAround(_threatCenter);
    // Tick económico 4 veces por segundo (suficiente para un contador en vivo).
    // El guardado va debounced en el SaveStore → el tick no pega al disco salvo
    // una vez cada par de segundos.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_territory.claimedCount == 0) return;
      _territory.produce(0.25);
      _scheduleSave();
      notifyListeners();
    });
  }

  final HexGridService _gridService;
  final TerritoryRepository _territory;
  final ThreatService _threatService;
  final SaveStore? _saveStore;
  late final List<Hex> _hexes;
  late List<MapMarker> _threats;
  late LatLng _threatCenter;
  Timer? _ticker;
  double _zoom;

  static const Distance _distance = Distance();

  /// Radio (m) dentro del cual se puede atacar una amenaza desde un anclaje
  /// (tu posición, tu campamento o tu base). Fuera de todos los radios, la
  /// amenaza no es atacable directo (futuro: viajar con km+tiempo, doc 19).
  ///
  /// **Futuro (doc 21):** es el **stat semilla mejorable** — migrar de `const` a
  /// un campo de `PlayerStats` (la base lo sube con su nivel) sin tocar la regla
  /// de proximidad. Acotado a propósito por anti-idle (doc 05).
  static const double attackRadiusMeters = 300;

  // --- Snapshots inmutables para la View ---
  List<Hex> get hexes => List.unmodifiable(_hexes);
  double get supplies => _territory.supplies;
  int get claimedCount => _territory.claimedCount;
  double get productionPerMinute => _territory.productionPerSecond * 60;
  double get zoom => _zoom;
  bool isClaimed(int hexId) => _territory.isClaimed(hexId);

  /// Amenazas visibles (grupos de zombies, etc.). Deterministas por posición.
  List<MapMarker> get threats => List.unmodifiable(_threats);

  // --- Asentamientos y posición del jugador (GPS simulado) ---
  LatLng get playerPosition => _territory.playerPosition;
  Outpost? get camp => _territory.camp;
  Outpost? get base => _territory.base;
  bool get hasBase => _territory.hasBase;
  double get campCost => _territory.campCost;
  double get baseCost => _territory.baseCost;
  bool get canAffordCamp => _territory.supplies >= _territory.campCost;
  bool get canAffordBase => _territory.supplies >= _territory.baseCost;

  /// Anclajes desde los que se puede atacar: tu posición + campamento + base.
  Iterable<LatLng> get attackAnchors sync* {
    yield _territory.playerPosition;
    final c = _territory.camp;
    if (c != null) yield c.position;
    final b = _territory.base;
    if (b != null) yield b.position;
  }

  /// ¿La amenaza está dentro del radio de ataque de algún anclaje?
  bool canAttack(MapMarker threat) {
    for (final a in attackAnchors) {
      if (_distance(a, threat.position) <= attackRadiusMeters) return true;
    }
    return false;
  }

  /// Distancia (m) de la amenaza al anclaje más cercano (para el hint del popup).
  double distanceToNearestAnchor(MapMarker threat) {
    var best = double.infinity;
    for (final a in attackAnchors) {
      final d = _distance(a, threat.position);
      if (d < best) best = d;
    }
    return best;
  }

  /// Mueve la posición del jugador (simula caminar hasta [pos]).
  void movePlayerTo(LatLng pos) {
    _territory.movePlayerTo(pos);
    _scheduleSave();
    notifyListeners();
  }

  /// Coloca/mueve el campamento temporal en [pos] (libre, en cualquier lado).
  BuildResult placeCamp(LatLng pos) {
    final r = _territory.placeCamp(pos);
    if (r == BuildResult.success) {
      _scheduleSave();
      notifyListeners();
    }
    return r;
  }

  /// Funda la base permanente **en la posición actual del jugador** (regla de
  /// presencia/GPS). Se ancla al hexágono más cercano a esa posición (doc 15).
  BuildResult foundBaseAtPlayer() {
    final hex = _gridService.nearestHexTo(_territory.playerPosition, _hexes);
    final r = _territory.foundBase(
      playerPosition: _territory.playerPosition,
      hexId: hex?.id,
    );
    if (r == BuildResult.success) {
      _scheduleSave();
      notifyListeners();
    }
    return r;
  }

  // --- Persistencia (doc 22) ---
  void _scheduleSave() => _saveStore?.save(_territory.toSave());

  /// Guarda **ya y sincrónico** el estado. Para el cierre/pausa de la app, donde
  /// un write async podría no completar antes de que el proceso muera (p. ej. el
  /// botón de cerrar). Barato (JSON chico) y solo en el cierre.
  void saveNow() => _saveStore?.flushSync(_territory.toSave());

  /// Intenta reclamar el hexágono más cercano a [point]. Devuelve el resultado
  /// para que la View muestre feedback, o `null` si el toque cayó fuera de la
  /// grilla (no-op).
  ClaimResult? claimNearest(LatLng point) {
    final hex = _gridService.nearestHexTo(point, _hexes);
    if (hex == null) return null;
    final result = _territory.claim(hex.id);
    if (result == ClaimResult.success) {
      _scheduleSave();
      notifyListeners();
    }
    return result;
  }

  /// Reinicia la economía al estado inicial (y persiste el estado limpio).
  void reset() {
    _territory.reset();
    _scheduleSave();
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
