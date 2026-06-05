import 'package:latlong2/latlong.dart';

/// Tipo de amenaza/punto en el mapa. **Extensible:** sumar `boss`/`dungeon` reales
/// = agregar el valor acá + su icono en el render (ADR 0007: mapa con iconos).
enum MarkerKind { zombieGroup, boss, dungeon, base }

extension MarkerKindInfo on MarkerKind {
  String get label => switch (this) {
        MarkerKind.zombieGroup => 'Grupo de zombies',
        MarkerKind.boss => 'Boss',
        MarkerKind.dungeon => 'Dungeon',
        MarkerKind.base => 'Base',
      };

  /// Glyph del icono en el mapa (placeholder hasta tener sprites).
  String get emoji => switch (this) {
        MarkerKind.zombieGroup => '🧟',
        MarkerKind.boss => '💀',
        MarkerKind.dungeon => '🌀',
        MarkerKind.base => '🛡️',
      };
}

/// Familia de enemigo dentro de una amenaza (para el detalle del popup).
enum EnemyType { caminante, corredor, tanque }

extension EnemyTypeInfo on EnemyType {
  String get label => switch (this) {
        EnemyType.caminante => 'Caminante',
        EnemyType.corredor => 'Corredor',
        EnemyType.tanque => 'Tanque',
      };

  String get emoji => switch (this) {
        EnemyType.caminante => '🧟',
        EnemyType.corredor => '🏃',
        EnemyType.tanque => '🪓',
      };
}

/// Cuántos enemigos de un [type] hay en la amenaza.
class EnemyGroup {
  const EnemyGroup(this.type, this.count);
  final EnemyType type;
  final int count;
}

/// Una amenaza/punto en el mapa (lo que se dibuja como icono y se detalla en el
/// popup al tocar). **No se guarda en BD**: lo genera de forma determinista el
/// [ThreatService] a partir de la posición (doc 16) — mismo lugar = misma amenaza
/// para todos, calculable sin almacenar nada.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.kind,
    required this.difficulty,
    required this.enemies,
  });

  /// Id estable de la celda (futuro: hexId H3). Determinista por ubicación.
  final String id;
  final LatLng position;
  final MarkerKind kind;

  /// Dificultad 1 (fácil, cerca del spawn) … 5 (lejos/salvaje). Gradiente, doc 16.
  final int difficulty;
  final List<EnemyGroup> enemies;

  int get totalEnemies => enemies.fold(0, (a, e) => a + e.count);
}
