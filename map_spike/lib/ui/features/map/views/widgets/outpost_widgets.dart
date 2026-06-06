import 'package:flutter/material.dart';

import '../../../../../domain/models/outpost.dart';

/// Marker de la **posición del jugador** (GPS simulado): punto azul con halo.
/// Es desde donde se funda la base y uno de los anclajes de ataque.
class PlayerLocationMarker extends StatelessWidget {
  const PlayerLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7DEB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7DEB).withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Marker de un asentamiento (campamento ⛺ o base 🛡️) en el mapa.
class OutpostMarker extends StatelessWidget {
  const OutpostMarker({super.key, required this.kind});

  final OutpostKind kind;

  @override
  Widget build(BuildContext context) {
    final color =
        kind == OutpostKind.base ? const Color(0xFF46C66B) : const Color(0xFFE5B53D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(kind.emoji, style: const TextStyle(fontSize: 20)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            kind.label,
            style: const TextStyle(
                color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Menú de **construcción** (bottom sheet, zona del pulgar): mover mi ubicación,
/// poner/mover campamento, fundar base. Muestra el costo y deshabilita con motivo
/// si no alcanza o si ya hay base (skill UI: anticipar costos antes de confirmar).
class BuildMenuSheet extends StatelessWidget {
  const BuildMenuSheet({
    super.key,
    required this.hasCamp,
    required this.hasBase,
    required this.campCost,
    required this.baseCost,
    required this.canAffordCamp,
    required this.canAffordBase,
    required this.onMoveLocation,
    required this.onPlaceCamp,
    required this.onFoundBase,
  });

  final bool hasCamp;
  final bool hasBase;
  final double campCost;
  final double baseCost;
  final bool canAffordCamp;
  final bool canAffordBase;
  final VoidCallback onMoveLocation;
  final VoidCallback onPlaceCamp;
  final VoidCallback onFoundBase;

  @override
  Widget build(BuildContext context) {
    final baseEnabled = !hasBase && canAffordBase;
    final String baseSubtitle = hasBase
        ? 'Ya tenés una base permanente'
        : (!canAffordBase
            ? 'Te faltan suministros (cuesta ${baseCost.round()})'
            : 'Se funda en tu posición actual · cuesta ${baseCost.round()}');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text('Construir',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _BuildTile(
              emoji: '📍',
              title: 'Mover mi ubicación',
              subtitle: 'Tocá el mapa para "caminar" hasta ahí (GPS simulado)',
              enabled: true,
              onTap: onMoveLocation,
            ),
            _BuildTile(
              emoji: '⛺',
              title: hasCamp ? 'Mover campamento' : 'Poner campamento',
              subtitle: canAffordCamp
                  ? 'En cualquier lado · cuesta ${campCost.round()}'
                  : 'Te faltan suministros (cuesta ${campCost.round()})',
              enabled: canAffordCamp,
              onTap: onPlaceCamp,
            ),
            _BuildTile(
              emoji: '🛡️',
              title: 'Fundar base',
              subtitle: baseSubtitle,
              enabled: baseEnabled,
              onTap: onFoundBase,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildTile extends StatelessWidget {
  const _BuildTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.4;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          // Target alto (≥48dp) para el pulgar (skill UI).
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Opacity(
            opacity: opacity,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
