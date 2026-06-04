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
                  _EndOverlay(game: game, victory: false),
              kVictoryOverlay: (context, CombatGame game) =>
                  _EndOverlay(game: game, victory: true),
            },
          ),
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(child: BackButton(color: Colors.white)),
          ),
          // Id del template (debug) abajo-centro, lejos del HUD y el joystick.
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Text(
                  widget.template.id,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay de fin de escenario: victoria (cupo cumplido) o derrota (vida a 0).
class _EndOverlay extends StatelessWidget {
  const _EndOverlay({required this.game, required this.victory});

  final CombatGame game;
  final bool victory;

  @override
  Widget build(BuildContext context) {
    final title = victory ? 'Escenario completado' : 'Te alcanzaron';
    final color = victory ? const Color(0xFF46C66B) : Colors.redAccent;
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(victory ? Icons.military_tech : Icons.dangerous,
              color: color, size: 48),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Bajas: ${game.kills}   ·   Recursos: ${game.resources}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: game.restart,
            icon: Icon(victory ? Icons.replay : Icons.refresh),
            label: Text(victory ? 'Jugar de nuevo' : 'Reintentar'),
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
