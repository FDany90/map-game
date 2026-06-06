import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/player_save.dart';

/// Persiste el **save del jugador** como un JSON en *Application Support*
/// (`player_save.json`). Mismo patrón que el monitor de requests: IO aislado acá,
/// fuera del repositorio (que queda puro y testeable) — doc 22.
///
/// Las escrituras frecuentes (tick de economía) se **coalescan** con un debounce;
/// [flush] fuerza un guardado inmediato (para el pause de la app).
class SaveStore {
  File? _file;
  Timer? _saveTimer;
  PlayerSave? _pending;

  /// Carga el save del disco. Devuelve `null` si no existe, está corrupto o es de
  /// una versión incompatible (la app arranca de cero). Deja listo el archivo
  /// destino para los guardados posteriores.
  Future<PlayerSave?> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/player_save.json');
      if (!await _file!.exists()) return null;
      final raw = jsonDecode(await _file!.readAsString());
      if (raw is Map<String, dynamic>) return PlayerSave.fromJson(raw);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[save] no se pudo cargar el save: $e');
      return null;
    }
  }

  /// Programa un guardado **coalescido**: la primera llamada arma un timer de 2 s;
  /// las siguientes **no lo resetean**, solo actualizan el estado a escribir. Así
  /// una fuente de alta frecuencia (el tick de economía, 4×/s) **no** posterga la
  /// escritura para siempre — escribe el último estado a lo sumo cada 2 s.
  void save(PlayerSave save) {
    _pending = save;
    _saveTimer ??= Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      final p = _pending;
      _pending = null;
      if (p != null) _write(p);
    });
  }

  /// Guarda **ya y de forma SINCRÓNICA**. Se usa al cerrar/pausar la app: el write
  /// async del debounce (`save`) puede no completar si el proceso muere enseguida
  /// —p. ej. el botón de cerrar con `SystemNavigator.pop()` finaliza la actividad
  /// al instante—, así que acá bloqueamos hasta dejarlo en disco. El JSON es chico:
  /// el costo es despreciable y solo pasa en el cierre, no en el hot path.
  void flushSync(PlayerSave save) {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pending = null;
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(jsonEncode(save.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('[save] no se pudo guardar (sync): $e');
    }
  }

  Future<void> _write(PlayerSave save) async {
    final file = _file;
    if (file == null) return; // load() todavía no corrió (no hay destino)
    try {
      await file.writeAsString(jsonEncode(save.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('[save] no se pudo guardar el save: $e');
    }
  }
}
