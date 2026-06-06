import 'package:latlong2/latlong.dart';

import '../../config/app_config.dart';
import '../../domain/models/build_result.dart';
import '../../domain/models/claim_result.dart';
import '../../domain/models/outpost.dart';
import '../../domain/models/player_save.dart';

/// Fuente única de verdad del estado de territorio/economía del jugador.
///
/// Hoy es en memoria + un snapshot local (`SaveStore`, doc 22); cuando llegue el
/// backend (Etapa 6) esta clase pasa a ser la fachada sobre Supabase/Firebase,
/// sin tocar la UI ni el ViewModel. La persistencia (IO/ciclo de vida) vive
/// **afuera** (en el `SaveStore` + wiring) para que el repo siga siendo puro y
/// testeable: acá solo `toSave()`/`restore()` (serialización del estado).
class TerritoryRepository {
  TerritoryRepository({
    double initialSupplies = 50,
    this.claimCost = 10,
    this.yieldPerHexPerSecond = 0.5, // +0.5/seg por hex = +30/min
    this.campCost = 20,
    this.baseCost = 150,
    LatLng initialPlayerPosition = AppConfig.initialCenter,
  })  : _initialSupplies = initialSupplies,
        _supplies = initialSupplies,
        _initialPlayerPosition = initialPlayerPosition,
        _playerPosition = initialPlayerPosition;

  /// Tope del catch-up offline (doc 22): al reabrir se produce por el tiempo
  /// ausente, pero capeado a esto (más allá, el tiempo cerrado no rinde →
  /// anti-idle). Tunable.
  static const Duration offlineCatchUpCap = Duration(hours: 1);

  final double _initialSupplies;
  final LatLng _initialPlayerPosition;

  /// Costo en suministros de reclamar un hexágono.
  final double claimCost;

  /// Producción de suministros por hexágono reclamado, por segundo.
  final double yieldPerHexPerSecond;

  /// Costo de colocar (o mover) el campamento temporal. Barato.
  final double campCost;

  /// Costo de fundar la base permanente. Caro: requiere farmear antes (doc 16).
  final double baseCost;

  final Set<int> _claimedHexIds = <int>{};
  double _supplies;
  Outpost? _camp;
  Outpost? _base;
  LatLng _playerPosition;

  double get supplies => _supplies;

  /// Posición del jugador (GPS **simulado**, doc 20): nace en el spawn y se mueve
  /// tocando el mapa. Vive acá (estado del jugador) para entrar al save.
  LatLng get playerPosition => _playerPosition;
  void movePlayerTo(LatLng pos) => _playerPosition = pos;
  int get claimedCount => _claimedHexIds.length;
  double get productionPerSecond => _claimedHexIds.length * yieldPerHexPerSecond;
  bool isClaimed(int hexId) => _claimedHexIds.contains(hexId);

  /// Campamento temporal actual (o `null` si todavía no se puso ninguno).
  Outpost? get camp => _camp;

  /// Base permanente (o `null` si el jugador todavía no fundó base).
  Outpost? get base => _base;
  bool get hasBase => _base != null;

  /// Intenta reclamar [hexId], descontando [claimCost] si corresponde.
  ClaimResult claim(int hexId) {
    if (_claimedHexIds.contains(hexId)) return ClaimResult.alreadyOwned;
    if (_supplies < claimCost) return ClaimResult.notEnoughSupplies;
    _supplies -= claimCost;
    _claimedHexIds.add(hexId);
    return ClaimResult.success;
  }

  /// Coloca (o mueve) el **campamento temporal** a [pos]. Se puede en cualquier
  /// lado; solo cuesta [campCost]. Volver a llamarlo lo reubica (pagando otra vez).
  BuildResult placeCamp(LatLng pos) {
    if (_supplies < campCost) return BuildResult.notEnoughSupplies;
    _supplies -= campCost;
    _camp = Outpost(kind: OutpostKind.camp, position: pos);
    return BuildResult.success;
  }

  /// Funda la **base permanente** en [playerPosition] —que es donde el jugador
  /// está físicamente parado (regla de presencia/GPS, doc 16)— anclándola al
  /// hexágono [hexId] (doc 15). No se puede fundar a control remoto: para fundarla
  /// en otro lado, el jugador primero tiene que moverse hasta ahí.
  ///
  /// Es **permanente**: si ya hay base, falla ([BuildResult.alreadyHasBase]) —
  /// mover una base es una acción aparte y costosa (futuro).
  BuildResult foundBase({required LatLng playerPosition, int? hexId}) {
    if (_base != null) return BuildResult.alreadyHasBase;
    if (_supplies < baseCost) return BuildResult.notEnoughSupplies;
    _supplies -= baseCost;
    _base = Outpost(
      kind: OutpostKind.base,
      position: playerPosition,
      hexId: hexId,
    );
    return BuildResult.success;
  }

  /// Acumula la producción correspondiente a [dtSeconds] de juego.
  void produce(double dtSeconds) {
    if (_claimedHexIds.isEmpty) return;
    _supplies += productionPerSecond * dtSeconds;
  }

  /// Aplica el **catch-up offline acotado** (doc 22): produce por el tiempo
  /// transcurrido desde [lastSeenEpochMs], **capeado** a [offlineCatchUpCap].
  /// [now] es inyectable para tests.
  void applyOfflineCatchUp(int lastSeenEpochMs, {DateTime? now}) {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final elapsedMs = nowMs - lastSeenEpochMs;
    if (elapsedMs <= 0) return;
    final cappedMs =
        elapsedMs.clamp(0, offlineCatchUpCap.inMilliseconds).toInt();
    produce(cappedMs / 1000.0);
  }

  /// Snapshot serializable del estado actual (para el `SaveStore`). `lastSeen` se
  /// sella al momento de guardar.
  PlayerSave toSave() => PlayerSave(
        version: PlayerSave.currentVersion,
        supplies: _supplies,
        claimedHexIds: _claimedHexIds.toList(),
        playerPosition: _playerPosition,
        lastSeenEpochMs: DateTime.now().millisecondsSinceEpoch,
        camp: _camp,
        base: _base,
      );

  /// Restaura el estado desde un [save] cargado del disco.
  void restore(PlayerSave save) {
    _supplies = save.supplies;
    _claimedHexIds
      ..clear()
      ..addAll(save.claimedHexIds);
    _camp = save.camp;
    _base = save.base;
    _playerPosition = save.playerPosition;
  }

  /// Vuelve al estado inicial (suministros llenos, sin hexágonos ni asentamientos,
  /// posición en el spawn).
  void reset() {
    _claimedHexIds.clear();
    _supplies = _initialSupplies;
    _camp = null;
    _base = null;
    _playerPosition = _initialPlayerPosition;
  }
}
