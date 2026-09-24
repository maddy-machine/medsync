/// Replaced by [FusionInferenceService].
///
/// This file is intentionally left as a redirect so that any references in
/// the build system resolve cleanly while the codebase is migrated.
///
/// The old logistic-regression screening model has been superseded by the
/// YOLOv8-Pose + PatchTST cross-modal attention fusion pipeline.
/// See `lib/services/fusion_inference_service.dart`.
library;

// Re-export the model enum so that any code that imported ScreeningResult
// through this file continues to compile without changes.
export '../models/screening_result.dart';