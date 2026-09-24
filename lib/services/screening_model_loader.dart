/// Replaced by the cross-modal fusion pipeline.
///
/// The asset-backed logistic-regression model loader is no longer used.
/// Model loading now happens inside [FusionInferenceService] (stub path)
/// or via [PatchTSTSensorEncoder.loadWeights] / future TFLite calls when
/// real weights become available.
///
/// This stub is kept so that pubspec.yaml asset declarations and any
/// existing imports do not cause hard compile errors during the migration.
library;