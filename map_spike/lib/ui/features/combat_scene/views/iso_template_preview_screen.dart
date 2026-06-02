import 'package:flutter/material.dart';

import '../../../../domain/models/scene_template.dart';
import 'combat_play_screen.dart';
import 'widgets/iso_template_painter.dart';

/// Preview del **template de escena de combate en isométrico 2.5D** con cajas
/// placeholder (ADR 0007 Rev 3, doc 18 fase 4).
///
/// No necesita OSM: renderiza templates hechos a mano para **validar el layout y
/// el look iso** antes de tener assets. Los sliders dejan tunear la inclinación
/// (de calle vertical exacta → bien iso) y la cámara en vivo.
class IsoTemplatePreviewScreen extends StatefulWidget {
  const IsoTemplatePreviewScreen({super.key});

  @override
  State<IsoTemplatePreviewScreen> createState() => _IsoTemplatePreviewScreenState();
}

class _IsoTemplatePreviewScreenState extends State<IsoTemplatePreviewScreen> {
  late SceneTemplate _template = SceneTemplates.all.first;
  // Config de cámara ELEGIDA (2026-06-01). Define el ángulo ¾ del escenario de
  // combate → es el ángulo al que se renderizan los sprites en Blender (ADR 0007
  // Rev 3). Los sliders siguen para experimentar, pero estos son los valores base.
  double _skew = 0.35;
  double _pitch = 0.49;
  double _zoom = 4.10;
  double _panX = 0.01;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14171C),
      appBar: AppBar(
        title: const Text('Template iso (preview)'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Jugar (mover con joystick)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CombatPlayScreen(
                  template: _template,
                  zoom: _zoom,
                  skew: _skew,
                  pitch: _pitch,
                  panX: _panX,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de template.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                const Text('Template:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF20242B),
                    value: _template.id,
                    items: [
                      for (final t in SceneTemplates.all)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.id,
                              style: const TextStyle(color: Colors.white)),
                        ),
                    ],
                    onChanged: (id) => setState(() => _template =
                        SceneTemplates.all.firstWhere((t) => t.id == id)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: IsoTemplatePainter(
                template: _template,
                skew: _skew,
                pitch: _pitch,
                zoom: _zoom,
                panX: _panX,
              ),
              size: Size.infinite,
            ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.black.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _slider(
            'Zoom de cámara (calle ancha + edificios al borde →)',
            _zoom,
            1.0,
            6.0,
            (v) => setState(() => _zoom = v),
          ),
          _slider(
            'Cámara horizontal X (← izquierda · derecha →)',
            _panX,
            -0.6,
            0.6,
            (v) => setState(() => _panX = v),
          ),
          _slider(
            'Inclinación iso (0 = calle vertical exacta)',
            _skew,
            0,
            0.4,
            (v) => setState(() => _skew = v),
          ),
          _slider(
            'Cámara / profundidad (← más fachada · más cenital →)',
            _pitch,
            0.35,
            1.3,
            (v) => setState(() => _pitch = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _logConfig,
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Loguear config en consola'),
            ),
          ),
          Text(
            '${_template.id} · ${_template.countOf(SlotKind.buildingRow)} edificios · '
            '${_template.countOf(SlotKind.cornerLandmark)} POI · '
            'calle vertical + brújula (placeholder) — las cajas se reemplazan por '
            'sprites 3D pre-renderizados (ADR 0007 Rev 3)',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Imprime la config actual en la consola de `flutter run` para fijarla como
  /// default sin transcribir a mano.
  void _logConfig() {
    debugPrint('[iso-config] zoom=${_zoom.toStringAsFixed(3)} '
        'panX=${_panX.toStringAsFixed(3)} '
        'skew=${_skew.toStringAsFixed(3)} '
        'pitch=${_pitch.toStringAsFixed(3)} '
        'template=${_template.id}');
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  ·  ${value.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
