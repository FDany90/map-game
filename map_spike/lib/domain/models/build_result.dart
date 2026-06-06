/// Resultado de intentar construir/colocar un asentamiento (campamento o base).
enum BuildResult {
  /// Construido/colocado con éxito (se descontaron los suministros).
  success,

  /// No alcanzaban los suministros para el costo.
  notEnoughSupplies,

  /// Fundar base: ya tenés una base permanente (mover es otra acción, costosa).
  alreadyHasBase,
}

extension BuildResultMessage on BuildResult {
  /// Mensaje corto para feedback en la UI (snackbar). `null` si fue éxito.
  String? get error => switch (this) {
        BuildResult.success => null,
        BuildResult.notEnoughSupplies => 'No te alcanzan los suministros',
        BuildResult.alreadyHasBase => 'Ya tenés una base permanente',
      };
}
