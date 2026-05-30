/// De dónde salieron las calles que se están usando.
enum StreetsSource {
  /// Descargadas en vivo de Overpass (OSM real).
  overpass,

  /// Leídas de la caché en disco (OSM real, bajadas antes).
  cache,

  /// Calles sintéticas de respaldo (sin red y sin caché).
  fallback,
}
