import 'package:flutter_test/flutter_test.dart';
import 'package:medsync_app/models/camera_vision_result.dart';
import 'package:medsync_app/models/imu_data.dart';
import 'package:medsync_app/models/imu_embedding.dart';
import 'package:medsync_app/models/patient_assessment.dart';
import 'package:medsync_app/models/pose_estimation_result.dart';
import 'package:medsync_app/models/screening_result.dart';
import 'package:medsync_app/models/sensor_sample.dart';
import 'package:medsync_app/services/fusion_inference_service.dart';
import 'package:medsync_app/services/mock_sensor_service.dart';
import 'package:medsync_app/services/movement_test_controller.dart';
import 'package:medsync_app/services/patchtst_sensor_encoder.dart';
import 'package:medsync_app/services/pose_estimation_service.dart';

void main() {
  group('YOLOv8-Pose Vision Branch Tests', () {
    test('PoseEstimationResult JSON serialization & 17 COCO keypoints', () {
      final now = DateTime.now();
      final keypoints = [
        const Keypoint(name: 'nose', x: 0.5, y: 0.08, confidence: 0.98),
        const Keypoint(name: 'left_knee', x: 0.43, y: 0.72, confidence: 0.94),
        const Keypoint(name: 'right_knee', x: 0.57, y: 0.72, confidence: 0.93),
      ];

      final result = PoseEstimationResult(
        keypoints: keypoints,
        kneeValgusAngle: 12.5,
        trunkLateralShift: 0.035,
        hipKneeFlexionAngle: 72.0,
        overallPoseConfidence: 0.95,
        riskLevel: ScreeningRiskLevel.moderate,
        isStubResult: true,
        capturedAt: now,
      );

      final json = result.toJson();
      expect(json['knee_valgus_angle'], 12.5);
      expect(json['trunk_lateral_shift'], 0.035);
      expect(json['hip_knee_flexion_angle'], 72.0);
      expect(json['overall_pose_confidence'], 0.95);
      expect(json['risk_level'], 'moderate');
      expect(json['is_stub_result'], isTrue);

      final reconstructed = PoseEstimationResult.fromJson(json);
      expect(reconstructed.kneeValgusAngle, 12.5);
      expect(reconstructed.trunkLateralShift, 0.035);
      expect(reconstructed.keypoints.length, 3);
      expect(reconstructed.keypoints.first.name, 'nose');
      expect(reconstructed.riskLevel, ScreeningRiskLevel.moderate);
    });

    test('StubYoloV8PoseService produces 17 keypoints and clinical angles', () async {
      const service = StubYoloV8PoseService();
      const assessment = PatientAssessment(
        painScore: 8,
        stiffnessScore: 7,
        functionalDifficultyScore: 8,
        activityRelatedPain: true,
        morningStiffness: true,
      );

      final result = await service.estimatePose(
        videoPath: '/mock/path/gait.mp4',
        patientAssessment: assessment,
      );

      expect(result.keypoints.length, 17);
      expect(result.isStubResult, isTrue);
      expect(result.overallPoseConfidence, greaterThan(0.7));
      expect(result.kneeValgusAngle, greaterThan(0));
      expect(result.riskLevel, isNotNull);
    });
  });

  group('PatchTST Sensor Branch Tests', () {
    test('PatchTSTSensorEncoder encodes IMU window into d_model embedding', () {
      final encoder = PatchTSTSensorEncoder(
        config: const PatchTSTConfig(
          inputChannels: 6,
          patchSize: 16,
          patchStride: 16,
          dModel: 64,
          nHeads: 4,
          nLayers: 2,
        ),
      );

      // Generate 48 samples (3 full patches)
      final samples = List.generate(
        48,
        (i) => SensorSample(
          timestamp: i * 20,
          thigh: ImuData(
            ax: 0.1 * (i % 5),
            ay: 9.8 + 0.2 * (i % 3),
            az: 0.05,
            gx: 0.02 * i,
            gy: 0.01,
            gz: 0.03,
          ),
          shin: ImuData(
            ax: 0.12 * (i % 5),
            ay: 9.7 + 0.15 * (i % 3),
            az: 0.04,
            gx: 0.025 * i,
            gy: 0.015,
            gz: 0.035,
          ),
        ),
      );

      final embedding = encoder.encode(samples);

      expect(embedding.embedding.length, 64);
      expect(embedding.patchAttentionWeights.isNotEmpty, isTrue);
      expect(embedding.microTremorScore, inInclusiveRange(0.0, 1.0));
      expect(embedding.gaitIrregularityScore, inInclusiveRange(0.0, 1.0));
      expect(embedding.isStubResult, isTrue);

      final json = embedding.toJson();
      final reconstructed = ImuEmbedding.fromJson(json);
      expect(reconstructed.embedding.length, 64);
      expect(reconstructed.microTremorScore, embedding.microTremorScore);
    });
  });

  group('Cross-Modal Attention Fusion Tests', () {
    test('FusionInferenceService produces valid FusedRiskResult and insights', () async {
      final fusionService = FusionInferenceService();

      final poseResult = PoseEstimationResult(
        keypoints: const [],
        kneeValgusAngle: 14.5,
        trunkLateralShift: 0.04,
        hipKneeFlexionAngle: 68.0,
        overallPoseConfidence: 0.92,
        riskLevel: ScreeningRiskLevel.moderate,
        isStubResult: true,
        capturedAt: DateTime.now(),
      );

      final imuEmbedding = ImuEmbedding(
        embedding: List.filled(64, 0.25),
        patchAttentionWeights: [0.33, 0.33, 0.34],
        microTremorScore: 0.45,
        gaitIrregularityScore: 0.50,
        bilateralSymmetryScore: 0.85,
        isStubResult: true,
        encodedAt: DateTime.now(),
      );

      const patientAssessment = PatientAssessment(
        painScore: 5,
        stiffnessScore: 4,
        functionalDifficultyScore: 5,
        activityRelatedPain: true,
        morningStiffness: false,
      );

      final fused = fusionService.fuse(
        poseResult: poseResult,
        imuEmbedding: imuEmbedding,
        patientAssessment: patientAssessment,
      );

      expect(fused.fusedRiskScore, inInclusiveRange(0.0, 1.0));
      expect(fused.fusionConfidence, inInclusiveRange(0.0, 1.0));
      expect(fused.cameraContribution + fused.sensorContribution, closeTo(1.0, 0.01));
      expect(fused.modalityAgreement, inInclusiveRange(0.0, 1.0));
      expect(fused.insights.isNotEmpty, isTrue);
      expect(fused.isStubResult, isTrue);
    });
  });

  group('MovementTestController Fusion Lifecycle Integration', () {
    test('Controller handles pose estimation and fusion computation', () async {
      final mockSensorService = MockSensorService();
      final controller = MovementTestController(
        sensorService: mockSensorService,
      );

      controller.updatePatientAssessment(
        const PatientAssessment(
          painScore: 6,
          stiffnessScore: 5,
          functionalDifficultyScore: 6,
          activityRelatedPain: true,
          morningStiffness: true,
        ),
      );

      await controller.startNewScreening();

      // Trigger camera result processing which executes YOLOv8-Pose and fusion
      await controller.processCameraVisionResult(
        legacyResult: CameraVisionResult(
          postureScore: 78.0,
          gaitSymmetryIndex: 0.88,
          kneeFlexionAngleDeg: 105.0,
          stepCadence: 96.0,
          antalgicGaitScore: 24.0,
          riskLevel: ScreeningRiskLevel.moderate,
          isStubResult: true,
          capturedAt: DateTime.now(),
        ),
        videoPath: '/mock/test_video.mp4',
      );

      expect(controller.cameraVisionResult, isNotNull);
      expect(controller.poseEstimationResult, isNotNull);
      expect(controller.screeningSession.hasPoseEstimation, isTrue);
      expect(controller.screeningSession.hasCameraVision, isTrue);

      await controller.dispose();
    });
  });
}
