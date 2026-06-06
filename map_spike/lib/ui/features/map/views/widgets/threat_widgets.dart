import 'package:flutter/material.dart';

import '../../../../../domain/models/map_marker.dart';

/// Color por dificultad: 1 verde → 5 rojo (lenguaje visual consistente entre el
/// icono del mapa y el popup).
Color difficultyColor(int d) {
  const palette = [
    Color(0xFF46C66B),
    Color(0xFF9CCB3B),
    Color(0xFFE5B53D),
    Color(0xFFE5833D),
    Color(0xFFE5484D),
  ];
  return palette[(d - 1).clamp(0, 4)];
}

/// Icono de una amenaza en el mapa (tappable). El glyph y el color salen del
/// [marker], así el mismo widget sirve para zombies / boss / dungeon.
class ThreatMarker extends StatelessWidget {
  const ThreatMarker({super.key, required this.marker, required this.onTap});

  final MapMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = difficultyColor(marker.difficulty);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 2.5),
            ),
            alignment: Alignment.center,
            child: Text(marker.kind.emoji, style: const TextStyle(fontSize: 20)),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Niv ${marker.difficulty}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup (bottom sheet) con el detalle de una amenaza: dificultad, tipos de
/// enemigos y botón **Atacar** (que carga la escena de combate).
class ThreatDetailSheet extends StatelessWidget {
  const ThreatDetailSheet({
    super.key,
    required this.marker,
    required this.onAttack,
    this.canAttack = true,
    this.distanceMeters,
  });

  final MapMarker marker;
  final VoidCallback onAttack;

  /// Si la amenaza está dentro del radio de ataque (de tu posición/campamento/
  /// base). Si es `false`, "Atacar" se deshabilita con un motivo.
  final bool canAttack;

  /// Distancia al anclaje más cercano (para el hint cuando está fuera de rango).
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final c = difficultyColor(marker.difficulty);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa del sheet.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título: icono + nombre + badge de nivel.
            Row(
              children: [
                Text(marker.kind.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    marker.kind.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Nivel ${marker.difficulty}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Dificultad (pips).
            Row(
              children: [
                const Text('Dificultad',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 10),
                for (var i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i <= marker.difficulty
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 12,
                      color: i <= marker.difficulty ? c : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Enemigos',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            for (final g in marker.enemies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(g.type.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(g.type.label,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const Spacer(),
                    Text('×${g.count}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            // Hint de "fuera de alcance": por qué no se puede atacar y a qué
            // distancia está (regla de proximidad — atacás cerca de tu posición,
            // campamento o base).
            if (!canAttack) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location,
                        size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        distanceMeters == null
                            ? 'Fuera de alcance. Acercá tu campamento o tu posición.'
                            : 'A ${distanceMeters!.round()} m. Acercate (o mové tu '
                                'campamento) a menos de 300 m para atacar.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canAttack ? onAttack : null,
                    icon: Icon(canAttack
                        ? Icons.local_fire_department
                        : Icons.block),
                    label: Text(canAttack ? 'Atacar' : 'Fuera de alcance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE5484D),
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cerrar',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
