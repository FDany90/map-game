import '../../domain/models/claim_result.dart';

/// Fuente única de verdad del estado de territorio/economía del jugador.
///
/// Hoy es en memoria; cuando llegue el backend (Etapa 6) esta clase pasa a ser
/// la fachada sobre Supabase/Firebase, sin tocar la UI ni el ViewModel.
class TerritoryRepository {
  TerritoryRepository({
    double initialSupplies = 50,
    this.claimCost = 10,
    this.yieldPerHexPerSecond = 0.5, // +0.5/seg por hex = +30/min
  })  : _initialSupplies = initialSupplies,
        _supplies = initialSupplies;

  final double _initialSupplies;

  /// Costo en suministros de reclamar un hexágono.
  final double claimCost;

  /// Producción de suministros por hexágono reclamado, por segundo.
  final double yieldPerHexPerSecond;

  final Set<int> _claimedHexIds = <int>{};
  double _supplies;

  double get supplies => _supplies;
  int get claimedCount => _claimedHexIds.length;
  double get productionPerSecond => _claimedHexIds.length * yieldPerHexPerSecond;
  bool isClaimed(int hexId) => _claimedHexIds.contains(hexId);

  /// Intenta reclamar [hexId], descontando [claimCost] si corresponde.
  ClaimResult claim(int hexId) {
    if (_claimedHexIds.contains(hexId)) return ClaimResult.alreadyOwned;
    if (_supplies < claimCost) return ClaimResult.notEnoughSupplies;
    _supplies -= claimCost;
    _claimedHexIds.add(hexId);
    return ClaimResult.success;
  }

  /// Acumula la producción correspondiente a [dtSeconds] de juego.
  void produce(double dtSeconds) {
    if (_claimedHexIds.isEmpty) return;
    _supplies += productionPerSecond * dtSeconds;
  }

  /// Vuelve al estado inicial (suministros llenos, sin hexágonos).
  void reset() {
    _claimedHexIds.clear();
    _supplies = _initialSupplies;
  }
}
