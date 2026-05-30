import 'package:flutter/material.dart';

/// HUD de economía: barra superior con suministros, hexágonos, producción y zoom.
///
/// Widget "tonto": recibe todo por parámetro, no conoce el ViewModel.
class EconomyHud extends StatelessWidget {
  const EconomyHud({
    super.key,
    required this.supplies,
    required this.claimedCount,
    required this.productionPerMinute,
    required this.zoom,
  });

  final double supplies;
  final int claimedCount;
  final double productionPerMinute;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat(label: 'Suministros', value: supplies.toStringAsFixed(0)),
                _Stat(label: 'Hexágonos', value: '$claimedCount'),
                _Stat(
                  label: 'Producción',
                  value: '+${productionPerMinute.toStringAsFixed(0)}/min',
                ),
                _Stat(label: 'Zoom', value: zoom.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tocá un hexágono para reclamarlo (cuesta 10). Cada uno produce +30/min.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
