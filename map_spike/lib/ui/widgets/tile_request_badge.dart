import 'package:flutter/material.dart';

import '../../data/services/tile_request_monitor.dart';

/// Chip de diagnóstico que muestra, en vivo, cuántos **requests a MapTiler**
/// (cache misses = facturables) se gastaron en la prueba actual. Tocarlo cierra
/// la prueba: pone el contador en 0 e imprime el resumen por zoom en consola.
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
                    'MapTiler: ${m.session}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  if (m.total != m.session) ...[
                    const SizedBox(width: 4),
                    Text('(tot ${m.total})',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
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
