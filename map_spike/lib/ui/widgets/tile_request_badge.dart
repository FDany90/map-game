import 'package:flutter/material.dart';

import '../../data/services/tile_request_monitor.dart';

/// Chip de diagnóstico que muestra, en vivo, los **requests a MapTiler** (cache
/// misses = facturables): el acumulado **del día en UTC** (persistido, sobrevive
/// reinicios → comparable con el dashboard) y, entre paréntesis, los de la prueba
/// actual. Tocarlo cierra la prueba: pone el contador de run en 0 e imprime el
/// resumen por zoom en consola. El total del día NO se resetea (rola en UTC).
class TileRequestBadge extends StatelessWidget {
  const TileRequestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tileRequestMonitor,
      builder: (context, _) {
        final m = tileRequestMonitor;
        return Material(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: m.reset,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.satellite_alt,
                      size: 14, color: Colors.amberAccent),
                  const SizedBox(width: 6),
                  Text(
                    'MapTiler hoy: ${m.todayTotal}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Text('(run ${m.session})',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10)),
                  const SizedBox(width: 6),
                  const Icon(Icons.refresh, size: 13, color: Colors.white54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
