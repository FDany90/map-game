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
          GameWidget(game: _game),
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
