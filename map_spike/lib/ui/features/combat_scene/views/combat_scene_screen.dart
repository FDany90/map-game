import 'package:flutter/material.dart';

import '../../../../domain/models/combat_scene_layout.dart';
import '../../../../domain/models/osm_scene.dart';
import 'widgets/combat_scene_painter.dart';

/// Previsualización de la **escena de combate** generada desde OSM (Fase 2,
/// ADR 0007): top-down con profundidad falsa, calle principal vertical, brújula
/// con el norte real. Se entra desde el Inspector con la escena del punto tocado.
///
/// Render estático (CustomPainter) para validar la generación procedural; el
/// combate con personajes en movimiento migrará a Flame reusando el mismo layout.
class CombatSceneScreen extends StatelessWidget {
  const CombatSceneScreen({super.key, required this.scene});

  final OsmScene scene;

  @override
  Widget build(BuildContext context) {
    final layout = CombatSceneLayout.fromScene(scene);
    final walls = layout.buildings.length;

    return Scaffold(
      backgroundColor: const Color(0xFF14171C),
      appBar: AppBar(
        title: const Text('Escena de combate (preview)'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: CombatScenePainter(layout: layout),
              size: Size.infinite,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.black.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zona: ${layout.character.label}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'calles ${layout.streets.length} · '
                  'paredes generadas: $walls '
                  '(OSM detectó ${layout.realBuildingCount} edificios, usados como señal) · '
                  'calle principal vertical · la brújula marca el norte real',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
