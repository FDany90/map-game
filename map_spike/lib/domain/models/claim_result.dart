/// Resultado de intentar reclamar un hexágono.
enum ClaimResult {
  /// Reclamado con éxito (se descontaron suministros).
  success,

  /// El hexágono ya era del jugador (no-op).
  alreadyOwned,

  /// No alcanzaban los suministros para reclamarlo.
  notEnoughSupplies,
}
