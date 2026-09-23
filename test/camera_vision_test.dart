import 'package:flutter_test/flutter_test.dart';
import 'package:medsync_app/models/camera_vision_result.dart';
import 'package:medsync_app/models/patient_assessment.dart';
import 'package:medsync_app/models/screening_result.dart';
import 'package:medsync_app/services/camera_vision_inference_service.dart';
import 'package:medsync_app/services/mock_sensor_service.dart';
import 'package:medsync_app/services/movement_test_controller.dart';

void main() {
  group('CameraVisionResult Model Tests', () {
    test('CameraVisionResult json serialization and deserialization', () {
      final now = DateTime.now();
      final result = CameraVisionResult(
        postureScore: 86.5,
        gaitSymmetryIndex: 0.942,
        kneeFlexionAngleDeg: 115.0,
        stepCadence: 104.0,
        antalgicGaitScore: 16.2,
        riskLevel: ScreeningRiskLevel.lower,
        isStubResult: true,
        capturedAt: now,
        videoPath: '/path/to/movement_video.mp4',
        trackingConfidence: 0.95,
        kinematicFindings: [
          'Bilateral stance phase duration demonstrates normal symmetry.',
          'Peak knee flexion excursion is preserved within normal range.',
        ],
      );

      final json = result.toJson();
      expect(json['posture_score'], 86.5);
      expect(json['gait_symmetry_index'], 0.942);
      expect(json['knee_flexion_angle_deg'], 115.0);
      expect(json['step_cadence'], 104.0);
      expect(json['antalgic_gait_score'], 16.2);
      expect(json['risk_level'], 'lower');
      expect(json['is_stub_result'], isTrue);
      expect(json['video_path'], '/path/to/movement_video.mp4');

      final reconstructed = CameraVisionResult.fromJson(json);
      expect(reconstructed.postureScore, result.postureScore);
      expect(reconstructed.gaitSymmetryIndex, result.gaitSymmetryIndex);
      expect(reconstructed.kneeFlexionAngleDeg, result.kneeFlexionAngleDeg);
      expect(reconstructed.stepCadence, result.stepCadence);
      expect(reconstructed.antalgicGaitScore, result.antalgicGaitScore);
      expect(reconstructed.riskLevel, ScreeningRiskLevel.lower);
      expect(reconstructed.isStubResult, isTrue);
      expect(reconstructed.kinematicFindings.length, 2);
    });

    test('CameraVisionResult risk labels', () {
      final now = DateTime.now();
      expect(
        CameraVisionResult(
          postureScore: 90,
          gaitSymmetryIndex: 0.95,
          kneeFlexionAngleDeg: 110,
          stepCadence: 100,
          antalgicGaitScore: 10,
          riskLevel: ScreeningRiskLevel.lower,
          capturedAt: now,
        ).riskLabel,
        'Lower Risk Pattern',
      );

      expect(
        CameraVisionResult(
          postureScore: 75,
          gaitSymmetryIndex: 0.88,
          kneeFlexionAngleDeg: 95,
          stepCadence: 90,
          antalgicGaitScore: 25,
          riskLevel: ScreeningRiskLevel.moderate,
          capturedAt: now,
        ).riskLabel,
        'Moderate Risk Pattern',
      );

      expect(
        CameraVisionResult(
          postureScore: 60,
          gaitSymmetryIndex: 0.78,
          kneeFlexionAngleDeg: 80,
          stepCadence: 80,
          antalgicGaitScore: 45,
          riskLevel: ScreeningRiskLevel.higher,
          capturedAt: now,
        ).riskLabel,
        'Higher Risk Pattern',
      );
    });
  });

  group('StubCameraVisionInferenceService Tests', () {
    test('Generates deterministic plausible kinematics based on patient assessment', () async {
      const inferenceService = StubCameraVisionInferenceService();

      const assessment = PatientAssessment(
        age: 58,
        heightCm: 172.0,
        weightKg: 74.0,
        painScore: 2,
        stiffnessScore: 1,
        functionalDifficultyScore: 2,
        activityRelatedPain: true,
        morningStiffness: false,
      );

      final result = await inferenceService.analyzeVideo(
        videoPath: 'test_movement_sample.mp4',
        patientAssessment: assessment,
      );

      expect(result.postureScore, greaterThanOrEqualTo(50.0));
      expect(result.postureScore, lessThanOrEqualTo(100.0));
      expect(result.gaitSymmetryIndex, greaterThanOrEqualTo(0.65));
      expect(result.gaitSymmetryIndex, lessThanOrEqualTo(1.0));
      expect(result.kneeFlexionAngleDeg, greaterThanOrEqualTo(65.0));
      expect(result.kneeFlexionAngleDeg, lessThanOrEqualTo(135.0));
      expect(result.stepCadence, greaterThanOrEqualTo(70.0));
      expect(result.stepCadence, lessThanOrEqualTo(140.0));
      expect(result.antalgicGaitScore, greaterThanOrEqualTo(5.0));
      expect(result.antalgicGaitScore, lessThanOrEqualTo(90.0));
      expect(result.isStubResult, isTrue);
      expect(result.kinematicFindings, isNotEmpty);
    });
  });

  group('MovementTestController Integration with Camera Vision', () {
    test('MovementTestController manages camera vision state and reset lifecycle', () async {
      final mockSensorService = MockSensorService();
      final controller = MovementTestController(sensorService: mockSensorService);

      expect(controller.cameraVisionResult, isNull);
      expect(controller.screeningSession.hasCameraVision, isFalse);

      final dummyResult = CameraVisionResult(
        postureScore: 88.0,
        gaitSymmetryIndex: 0.94,
        kneeFlexionAngleDeg: 110.0,
        stepCadence: 105.0,
        antalgicGaitScore: 14.0,
        riskLevel: ScreeningRiskLevel.lower,
        capturedAt: DateTime.now(),
      );

      controller.setCameraVisionResult(dummyResult);
      expect(controller.cameraVisionResult, isNotNull);
      expect(controller.cameraVisionResult?.postureScore, 88.0);
      expect(controller.screeningSession.hasCameraVision, isTrue);

      await controller.startNewScreening();
      expect(controller.cameraVisionResult, isNull);
      expect(controller.screeningSession.hasCameraVision, isFalse);

      await controller.dispose();
      await mockSensorService.dispose();
    });
  });
}
