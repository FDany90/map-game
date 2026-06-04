import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/scene_template.dart';
import '../game/combat_game.dart';

/// Escena de combate **jugable**: el jugador se mueve por la calle estilo dungeon
/// con joystick (Flame). Recibe el template y la config de cámara ya elegida.
class CombatPlayScreen extends StatefulWidget {
  const CombatPlayScreen({
    super.key,
    required this.template,
    this.zoom = 4.10,
    this.skew = 0.35,
    this.pitch = 0.49,
    this.panX = 0.01,
  });

  final SceneTemplate template;
  final double zoom;
  final double skew;
  final double pitch;
  final double panX;

  @override
  State<CombatPlayScreen> createState() => _CombatPlayScreenState();
}

class _CombatPlayScreenState extends State<CombatPlayScreen> {
  late final CombatGame _game = CombatGame(
    template: widget.template,
    zoom: widget.zoom,
    skew: widget.skew,
    pitch: widget.pitch,
    panX: widget.panX,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              kGameOverOverlay: (context, CombatGame game) =>
                  _GameOverOverlay(game: game),
            },
          ),
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(child: BackButton(color: Colors.white)),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${widget.template.id} · movés con el joystick',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay de fin de partida: muestra las bajas y permite reintentar.
class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game});

  final CombatGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Te alcanzaron',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Bajas: ${game.kills}',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: game.restart,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Salir', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
