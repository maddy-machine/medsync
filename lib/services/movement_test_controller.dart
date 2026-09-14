import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../analysis/chair_stand_analyzer.dart';
import '../analysis/chair_stand_feature_extractor.dart';
import '../analysis/fast_walk_analyzer.dart';
import '../analysis/fast_walk_cycle_analyzer.dart';
import '../analysis/imu_signal_processor.dart';
import '../analysis/knee_angle_estimator.dart';
import '../analysis/knee_angle_features.dart';
import '../analysis/knee_motion_processor.dart';
import '../analysis/koa_feature_extractor.dart';
import '../analysis/movement_features.dart';
import '../models/movement_test.dart';
import '../models/patient_assessment.dart';
import '../models/screening_result.dart';
import '../models/sensor_sample.dart';
import '../models/sensor_session.dart';
import '../models/test_state.dart';
import '../validation/sensor_validator.dart';
import 'screening_inference_service.dart';
import 'sensor_service.dart';

class MovementTestController {
  final SensorService sensorService;

  final ScreeningInferenceService screeningInferenceService;

  StreamSubscription<SensorSample>? _subscription;
  StreamSubscription<SensorSample>? _calibrationSubscription;

  Timer? _testTimer;
  Timer? _calibrationTimer;

  Stopwatch? _recordingStopwatch;

  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  SensorSession? session;
  SensorSample? latestSample;
  final List<SensorSample> recentSamples = [];

  int sampleCount = 0;

  TestState _state = TestState.idle;

  int elapsedSeconds = 0;
  int preparationSeconds = 3;
  int calibrationSeconds = 3;

  MovementTest? _activeTest;

  bool _screeningStarted = false;
  bool _isCalibrating = false;
  bool _stoppingTest = false;

  PatientAssessment _patientAssessment =
      const PatientAssessment(
    painScore: 0,
    stiffnessScore: 0,
    functionalDifficultyScore: 0,
    activityRelatedPain: false,
    morningStiffness: false,
  );

  ChairStandResult? chairStandResult;
  MovementFeatureVector? chairStandFeatures;

  FastWalkResult? fastWalkResult;
  FastWalkCycleResult? fastWalkCycleResult;

  KneeAngleFeatures? chairStandKneeFeatures;
  KneeAngleFeatures? fastWalkKneeFeatures;

  MovementFeatureVector? combinedFeatures;

  ScreeningResult? screeningResult;

  final ScreeningSessionState screeningSession =
      ScreeningSessionState();

  KneeMotionProcessor? _kneeMotionProcessor;

  final ImuSignalProcessor _imuSignalProcessor =
      ImuSignalProcessor(
    emaAlpha: 0.25,
  );

  // ------------------------------------------------------------
  // TEST QUALITY
  //
  // These scores describe the quality/completeness of the
  // collected sensor data. They are NOT AI confidence scores
  // and do not represent clinical validity.
  // ------------------------------------------------------------

  TestQualityResult? chairStandQuality;
  TestQualityResult? fastWalkQuality;

  MovementTestController({
    required this.sensorService,
    ScreeningInferenceService? screeningInferenceService,
  }) : screeningInferenceService =
            screeningInferenceService ??
                const ScreeningInferenceService();

  TestState get state => _state;

  bool get isRunning =>
      _state == TestState.running;

  bool get isPreparing =>
      _state == TestState.preparing &&
      !_isCalibrating;

  bool get isCalibrating =>
      _isCalibrating;

  bool get isBusy =>
      isRunning ||
      isPreparing ||
      isCalibrating;

  bool get screeningStarted =>
      _screeningStarted;

  MovementTest? get activeTest =>
      _activeTest;

  PatientAssessment get patientAssessment =>
      _patientAssessment;

  Stream<void> get changes =>
      _changeController.stream;

  Duration get elapsedDuration =>
      _recordingStopwatch?.elapsed ??
      Duration.zero;

  bool get canFinishTest =>
      _state == TestState.running &&
      !_stoppingTest;

  bool get bothTestsCompleted =>
      screeningSession.hasChairStand &&
      screeningSession.hasFastWalk;

  bool get isScreeningReady =>
      bothTestsCompleted &&
      combinedFeatures != null;

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  void updatePatientAssessment(
    PatientAssessment assessment,
  ) {
    _patientAssessment = assessment;

    if (!screeningSession.hasChairStand ||
        !screeningSession.hasFastWalk) {
      screeningResult = null;
    }

    _notifyChanged();
  }

  Future<void> startNewScreening() async {
    if (isBusy) {
      return;
    }

    await _cleanupCurrentTest();

    _screeningStarted = true;

    screeningSession.reset();

    session = null;
    latestSample = null;
    sampleCount = 0;
    recentSamples.clear();

    chairStandResult = null;
    chairStandFeatures = null;
    chairStandKneeFeatures = null;
    chairStandQuality = null;

    fastWalkResult = null;
    fastWalkCycleResult = null;
    fastWalkKneeFeatures = null;
    fastWalkQuality = null;

    combinedFeatures = null;

    screeningResult = null;

    _kneeMotionProcessor?.reset();
    _kneeMotionProcessor = null;

    _imuSignalProcessor.reset();

    _recordingStopwatch = null;
    _stoppingTest = false;

    elapsedSeconds = 0;
    preparationSeconds = 3;
    calibrationSeconds = 3;

    _activeTest = null;
    _isCalibrating = false;

    _state = TestState.idle;
    _notifyChanged();
  }

  Future<void> startTest(
    MovementTest test,
  ) async {
    if (isBusy) {
      return;
    }

    if (!_screeningStarted) {
      _screeningStarted = true;
    }

    _activeTest = test;

    elapsedSeconds = 0;
    preparationSeconds = 3;
    calibrationSeconds = 3;

    _isCalibrating = false;
    _stoppingTest = false;

    _recordingStopwatch = null;

    latestSample = null;
    sampleCount = 0;

    if (test.type ==
        MovementTestType.chairStand) {
      chairStandResult = null;
      chairStandFeatures = null;
      chairStandKneeFeatures = null;
      chairStandQuality = null;
    } else {
      fastWalkResult = null;
      fastWalkCycleResult = null;
      fastWalkKneeFeatures = null;
      fastWalkQuality = null;
    }

    _kneeMotionProcessor =
        KneeMotionProcessor(
      beta: 0.1,
      flexionAxis: FlexionAxis.y,
    );

    _imuSignalProcessor.reset();

    session = SensorSession(
      sessionId: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      patientId: 'DEMO-001',
      testType: test.name,
      startTime:
          DateTime.now().millisecondsSinceEpoch,

      // ESP32 firmware streams at 50 Hz.
      samplingRate: 50,
    );

    _state = TestState.preparing;
    _notifyChanged();

    await _runPreparation();

    if (_state != TestState.preparing) {
      return;
    }

    await _runCalibration();

    if (_state != TestState.preparing) {
      return;
    }

    if (!_imuSignalProcessor.isCalibrated) {
      _state = TestState.failed;
      _notifyChanged();
      return;
    }

    await _startRecording(test);
  }

  Future<void> _runPreparation() async {
    for (int i = 3; i > 0; i--) {
      if (_state != TestState.preparing) {
        return;
      }

      preparationSeconds = i;
      _notifyChanged();

      await Future<void>.delayed(
        const Duration(seconds: 1),
      );
    }
  }

  Future<void> _runCalibration() async {
    _isCalibrating = true;
    calibrationSeconds = 3;

    _imuSignalProcessor.startCalibration();

    _notifyChanged();

    _calibrationSubscription =
        sensorService.sampleStream.listen(
      (sample) {
        _imuSignalProcessor
            .addCalibrationSample(sample);
      },
      onError: (_) {
        _isCalibrating = false;
        _state = TestState.failed;
        _notifyChanged();
      },
    );

    await sensorService.start();

    for (int i = 3; i > 0; i--) {
      if (_state != TestState.preparing) {
        _isCalibrating = false;
        await _stopCalibrationStream();
        return;
      }

      calibrationSeconds = i;
      _notifyChanged();

      await Future<void>.delayed(
        const Duration(seconds: 1),
      );
    }

    await _stopCalibrationStream();

    final calibrated =
        _imuSignalProcessor
            .finishCalibration();

    _isCalibrating = false;

    if (!calibrated) {
      _state = TestState.failed;
    }

    _notifyChanged();
  }

  Future<void> _stopCalibrationStream() async {
    await sensorService.stop();

    await _calibrationSubscription
        ?.cancel();

    _calibrationSubscription = null;
  }

  Future<void> _startRecording(
    MovementTest test,
  ) async {
    _subscription =
        sensorService.sampleStream.listen(
      (sample) {
        final filteredSample =
            _imuSignalProcessor.process(
          sample,
        );

        session?.addSample(
          filteredSample,
        );

        latestSample = filteredSample;
        recentSamples.add(filteredSample);

        if (recentSamples.length > 500) {
          recentSamples.removeAt(0);
        }

        sampleCount =
            session?.sampleCount ?? 0;

        _kneeMotionProcessor
            ?.processSample(
          filteredSample,
        );

        _notifyChanged();
      },
      onError: (_) {
        _state = TestState.failed;
        _recordingStopwatch?.stop();
        _notifyChanged();
      },
    );

    await sensorService.start();

    if (_state != TestState.preparing) {
      await _subscription?.cancel();
      _subscription = null;
      return;
    }

    _state = TestState.running;

    _recordingStopwatch =
        Stopwatch()..start();

    elapsedSeconds = 0;

    _notifyChanged();

    /*
     * The stopwatch is the source of truth for
     * elapsed recording time.
     *
     * Timer.periodic only refreshes the UI.
     *
     * Chair Stand:
     * automatically finishes at 30 seconds.
     *
     * Fast Walk:
     * user finishes manually after completing
     * the 20 metre walk.
     *
     * The 120 second duration is retained as
     * a safety timeout.
     */
    _testTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        if (_state != TestState.running) {
          timer.cancel();
          return;
        }

        final stopwatch =
            _recordingStopwatch;

        if (stopwatch == null) {
          return;
        }

        final duration =
            stopwatch.elapsed;

        elapsedSeconds =
            duration.inSeconds;

        _notifyChanged();

        if (test.type ==
                MovementTestType.chairStand &&
            duration >=
                test.duration) {
          await stopTest();
          return;
        }

        if (test.type ==
                MovementTestType.fastWalk &&
            duration >=
                test.duration) {
          await stopTest();
        }
      },
    );
  }

  Future<ValidationResult?> stopTest() async {
    if (_state != TestState.running ||
        _stoppingTest) {
      return null;
    }

    _stoppingTest = true;

    _recordingStopwatch?.stop();

    final stopwatch =
        _recordingStopwatch;

    if (stopwatch != null) {
      elapsedSeconds =
          stopwatch.elapsed.inSeconds;
    }

    _testTimer?.cancel();
    _testTimer = null;

    await sensorService.stop();

    await _subscription?.cancel();

    _subscription = null;

    session?.finish();

    final samples =
        session?.samples ??
            <SensorSample>[];

    sampleCount = samples.length;

    latestSample ??=
        samples.isNotEmpty
            ? samples.last
            : null;

    if (session != null) {
      elapsedSeconds =
          session!.durationSeconds.floor();
    }

    final result =
        SensorValidator.validate(
      samples,
    );

    debugPrint('[MedSync] Validation: ${result.isValid ? "PASS" : "FAIL"} | samples=${samples.length}');
    if (!result.isValid) {
      for (final issue in result.issues) {
        debugPrint('[MedSync] Validation issue: $issue');
      }
    }

    // Calculate quality even when validation fails,
    // so the UI can explain that the recording needs
    // improvement rather than silently hiding the issue.
    final quality =
        _calculateTestQuality(
      samples: samples,
      testType: _activeTest?.type,
    );

    if (_activeTest?.type ==
        MovementTestType.chairStand) {
      chairStandQuality = quality;
    } else if (_activeTest?.type ==
        MovementTestType.fastWalk) {
      fastWalkQuality = quality;
    }

    if (!result.isValid) {
      _state = TestState.failed;
      _stoppingTest = false;
      _notifyChanged();
      return result;
    }

    if (_activeTest?.type ==
        MovementTestType.chairStand) {
      _analyzeChairStand(samples);
    } else if (_activeTest?.type ==
        MovementTestType.fastWalk) {
      _analyzeFastWalk(samples);
    }

    _state = TestState.completed;

    if (_activeTest?.type ==
        MovementTestType.chairStand) {
      screeningSession.hasChairStand =
          true;
    }

    if (_activeTest?.type ==
        MovementTestType.fastWalk) {
      screeningSession.hasFastWalk =
          true;
    }

    _buildCombinedFeatures();

    _runAiScreeningIfReady();

    _stoppingTest = false;

    _notifyChanged();

    return result;
  }

  void _analyzeChairStand(
    List<SensorSample> samples,
  ) {
    chairStandResult =
        ChairStandAnalyzer.analyze(
      samples,
    );

    chairStandFeatures =
        ChairStandFeatureExtractor.extract(
      samples: samples,
      analysis: chairStandResult!,
    );

    if (_kneeMotionProcessor != null) {
      chairStandKneeFeatures =
          _kneeMotionProcessor!
              .calculateFeatures();
    }
  }

  void _analyzeFastWalk(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      fastWalkResult = null;
      fastWalkCycleResult = null;
      fastWalkKneeFeatures = null;
      return;
    }

    fastWalkResult =
        FastWalkResult.analyze(
      samples,
    );

    fastWalkCycleResult =
        FastWalkCycleResult.analyze(
      samples,
    );

    if (_kneeMotionProcessor != null) {
      fastWalkKneeFeatures =
          _kneeMotionProcessor!
              .calculateFeatures();
    }
  }

  void _buildCombinedFeatures() {
    final samples =
        session?.samples ??
            <SensorSample>[];

    if (samples.isEmpty) {
      combinedFeatures = null;
      screeningResult = null;
      return;
    }

    combinedFeatures =
        KoaFeatureExtractor.extract(
      samples: samples,
      patientAssessment:
          _patientAssessment,
    );
  }

  void _runAiScreeningIfReady() {
    if (!screeningSession.hasChairStand ||
        !screeningSession.hasFastWalk) {
      screeningResult = null;
      return;
    }

    final features =
        combinedFeatures;

    if (features == null) {
      screeningResult = null;
      return;
    }

    try {
      screeningResult =
          screeningInferenceService
              .evaluate(
        features,
      );
    } catch (error) {
      screeningResult =
          ScreeningResult(
        riskLevel:
            ScreeningRiskLevel.unavailable,
        probability: null,
        threshold: null,
        modelAvailable: false,
        modelVersion:
            'INFERENCE_ERROR',
        contributingFactors: [],
        explanation:
            'The AI screening pipeline could '
            'not safely evaluate the collected '
            'features.',
        recommendation:
            'Clinical evaluation is recommended. '
            'AI screening is unavailable for '
            'this assessment.',
      );
    }
  }

  // ------------------------------------------------------------
  // TEST QUALITY CALCULATION
  // ------------------------------------------------------------

  TestQualityResult _calculateTestQuality({
    required List<SensorSample> samples,
    required MovementTestType? testType,
  }) {
    if (samples.isEmpty) {
      return const TestQualityResult(
        score: 0,
        label: 'Poor',
        sampleCount: 0,
        durationSeconds: 0,
        samplingRate: 0,
        sampleCoverage: 0,
        timestampRegularity: 0,
        signalQuality: 0,
        movementPresence: 0,
      );
    }

    final duration =
        _calculateSampleDuration(samples);

    final samplingRate =
        _calculateActualSamplingRate(
      samples,
    );

    final sampleCoverage =
        _calculateSampleCoverage(
      samples,
      duration,
    );

    final timestampRegularity =
        _calculateTimestampRegularity(
      samples,
    );

    final signalQuality =
        _calculateSignalQuality(
      samples,
    );

    final movementPresence =
        _calculateMovementPresence(
      samples,
    );

    /*
     * Weighting:
     *
     * 25% sample coverage
     * 25% timestamp regularity
     * 25% sensor signal quality
     * 25% movement presence
     *
     * Duration is incorporated into sample coverage.
     *
     * testType is retained as an explicit input so
     * different movement-specific quality rules can
     * be introduced later without changing the API.
     */
    final score =
        (
          sampleCoverage * 0.25 +
          timestampRegularity * 0.25 +
          signalQuality * 0.25 +
          movementPresence * 0.25
        )
            .clamp(0.0, 100.0)
            .toDouble();

    return TestQualityResult(
      score: score,
      label: _qualityLabel(score),
      sampleCount: samples.length,
      durationSeconds: duration,
      samplingRate: samplingRate,
      sampleCoverage: sampleCoverage,
      timestampRegularity: timestampRegularity,
      signalQuality: signalQuality,
      movementPresence: movementPresence,
    );
  }

  double _calculateSampleDuration(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      return 0;
    }

    final duration =
        (samples.last.timestamp -
                samples.first.timestamp) /
            1000.0;

    if (!duration.isFinite ||
        duration < 0) {
      return 0;
    }

    return duration;
  }

  double _calculateActualSamplingRate(
    List<SensorSample> samples,
  ) {
    final duration =
        _calculateSampleDuration(
      samples,
    );

    if (duration <= 0) {
      return 0;
    }

    final rate =
        samples.length / duration;

    if (!rate.isFinite) {
      return 0;
    }

    return rate;
  }

  double _calculateSampleCoverage(
    List<SensorSample> samples,
    double duration,
  ) {
    if (samples.length < 2 ||
        duration <= 0) {
      return 0;
    }

    // ESP32 firmware streams one packet every 20 ms = 50 Hz.
    const expectedRate = 50.0;

    final expectedSamples =
        duration * expectedRate;

    if (expectedSamples <= 0) {
      return 0;
    }

    final coverage =
        samples.length / expectedSamples;

    /*
     * Values around 1.0 represent approximately
     * the expected 50 Hz stream.
     *
     * We cap the score at 100 so an unusually high
     * duplicate rate cannot inflate quality.
     */
    final normalized =
        min(coverage, 1.0);

    return (normalized * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  double _calculateTimestampRegularity(
    List<SensorSample> samples,
  ) {
    if (samples.length < 3) {
      return 0;
    }

    final intervals = <double>[];

    for (var i = 1;
        i < samples.length;
        i++) {
      final interval =
          samples[i].timestamp -
          samples[i - 1].timestamp;

      if (interval > 0) {
        intervals.add(
          interval.toDouble(),
        );
      }
    }

    if (intervals.isEmpty) {
      return 0;
    }

    final mean =
        intervals.reduce(
              (a, b) => a + b,
            ) /
            intervals.length;

    if (mean <= 0 ||
        !mean.isFinite) {
      return 0;
    }

    double variance = 0;

    for (final interval in intervals) {
      final difference =
          interval - mean;

      variance +=
          difference * difference;
    }

    variance /=
        intervals.length;

    final standardDeviation =
        sqrt(variance);

    final coefficient =
        standardDeviation / mean;

    if (!coefficient.isFinite) {
      return 0;
    }

    /*
     * A CV of 0 means perfectly regular timestamps.
     * Around 0.10 or below is treated as strong quality.
     */
    final score =
        (1.0 -
                (coefficient / 0.10))
            .clamp(0.0, 1.0);

    return score * 100;
  }

  double _calculateSignalQuality(
    List<SensorSample> samples,
  ) {
    if (samples.isEmpty) {
      return 0;
    }

    var validSamples = 0;

    for (final sample in samples) {
      final values = <double>[
        sample.thigh.ax,
        sample.thigh.ay,
        sample.thigh.az,
        sample.thigh.gx,
        sample.thigh.gy,
        sample.thigh.gz,
        sample.shin.ax,
        sample.shin.ay,
        sample.shin.az,
        sample.shin.gx,
        sample.shin.gy,
        sample.shin.gz,
      ];

      final allFinite =
          values.every(
        (value) => value.isFinite,
      );

      if (allFinite) {
        validSamples++;
      }
    }

    final ratio =
        validSamples / samples.length;

    return (ratio * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  double _calculateMovementPresence(
    List<SensorSample> samples,
  ) {
    if (samples.length < 2) {
      return 0;
    }

    final accelerationMagnitudes =
        <double>[];

    final gyroMagnitudes =
        <double>[];

    for (final sample in samples) {
      final thighAcceleration =
          _magnitude(
        sample.thigh.ax,
        sample.thigh.ay,
        sample.thigh.az,
      );

      final shinAcceleration =
          _magnitude(
        sample.shin.ax,
        sample.shin.ay,
        sample.shin.az,
      );

      final thighGyroscope =
          _magnitude(
        sample.thigh.gx,
        sample.thigh.gy,
        sample.thigh.gz,
      );

      final shinGyroscope =
          _magnitude(
        sample.shin.gx,
        sample.shin.gy,
        sample.shin.gz,
      );

      final acceleration =
          (thighAcceleration +
                  shinAcceleration) /
              2.0;

      final gyroscope =
          (thighGyroscope +
                  shinGyroscope) /
              2.0;

      if (acceleration.isFinite) {
        accelerationMagnitudes
            .add(acceleration);
      }

      if (gyroscope.isFinite) {
        gyroMagnitudes.add(gyroscope);
      }
    }

    if (accelerationMagnitudes.isEmpty ||
        gyroMagnitudes.isEmpty) {
      return 0;
    }

    final accelerationStd =
        _standardDeviation(
      accelerationMagnitudes,
    );

    final gyroscopeStd =
        _standardDeviation(
      gyroMagnitudes,
    );

    /*
     * The mock stream and real movement stream
     * should show some dynamic variation.
     *
     * These are deliberately broad prototype
     * thresholds rather than clinical cut-offs.
     */
    final accelerationScore =
        (accelerationStd / 0.50)
            .clamp(0.0, 1.0);

    final gyroscopeScore =
        (gyroscopeStd / 20.0)
            .clamp(0.0, 1.0);

    final score =
        (
          accelerationScore * 0.5 +
          gyroscopeScore * 0.5
        ) *
        100;

    return score
        .clamp(0.0, 100.0)
        .toDouble();
  }

  double _magnitude(
    double x,
    double y,
    double z,
  ) {
    return sqrt(
      x * x +
          y * y +
          z * z,
    );
  }

  double _standardDeviation(
    List<double> values,
  ) {
    if (values.length < 2) {
      return 0;
    }

    final mean =
        values.reduce(
              (a, b) => a + b,
            ) /
            values.length;

    double sum = 0;

    for (final value in values) {
      final difference =
          value - mean;

      sum +=
          difference * difference;
    }

    return sqrt(
      sum / values.length,
    );
  }

  String _qualityLabel(
    double score,
  ) {
    if (score >= 85) {
      return 'Good';
    }

    if (score >= 70) {
      return 'Acceptable';
    }

    if (score >= 50) {
      return 'Fair';
    }

    return 'Poor';
  }

  Future<void> cancelTest() async {
    await _cleanupCurrentTest();

    session = null;
    latestSample = null;
    sampleCount = 0;
    recentSamples.clear();

    chairStandResult = null;
    chairStandFeatures = null;
    chairStandKneeFeatures = null;
    chairStandQuality = null;

    fastWalkResult = null;
    fastWalkCycleResult = null;
    fastWalkKneeFeatures = null;
    fastWalkQuality = null;

    combinedFeatures = null;
    screeningResult = null;

    _kneeMotionProcessor?.reset();
    _kneeMotionProcessor = null;

    _imuSignalProcessor.reset();

    _recordingStopwatch = null;
    _stoppingTest = false;

    elapsedSeconds = 0;
    preparationSeconds = 3;
    calibrationSeconds = 3;

    _isCalibrating = false;
    _activeTest = null;

    _state = TestState.idle;

    _notifyChanged();
  }

  Future<void> _cleanupCurrentTest() async {
    _testTimer?.cancel();
    _testTimer = null;

    _calibrationTimer?.cancel();
    _calibrationTimer = null;

    _recordingStopwatch?.stop();
    _recordingStopwatch = null;

    await sensorService.stop();

    await _subscription?.cancel();
    _subscription = null;

    await _calibrationSubscription?.cancel();
    _calibrationSubscription = null;

    _kneeMotionProcessor?.reset();

    _stoppingTest = false;
  }

  Future<void> resetScreening() async {
    if (isBusy) {
      return;
    }

    await _cleanupCurrentTest();

    session = null;
    latestSample = null;
    sampleCount = 0;
    recentSamples.clear();

    chairStandResult = null;
    chairStandFeatures = null;
    chairStandKneeFeatures = null;
    chairStandQuality = null;

    fastWalkResult = null;
    fastWalkCycleResult = null;
    fastWalkKneeFeatures = null;
    fastWalkQuality = null;

    combinedFeatures = null;
    screeningResult = null;

    _kneeMotionProcessor = null;

    _imuSignalProcessor.reset();

    screeningSession.reset();

    _screeningStarted = false;
    _activeTest = null;

    _recordingStopwatch = null;
    _stoppingTest = false;

    elapsedSeconds = 0;
    preparationSeconds = 3;
    calibrationSeconds = 3;

    _isCalibrating = false;

    _state = TestState.idle;

    _notifyChanged();
  }

  Future<void> dispose() async {
    _testTimer?.cancel();
    _testTimer = null;
    recentSamples.clear();

    _calibrationTimer?.cancel();
    _calibrationTimer = null;

    _recordingStopwatch?.stop();
    _recordingStopwatch = null;

    await _subscription?.cancel();
    _subscription = null;

    await _calibrationSubscription?.cancel();
    _calibrationSubscription = null;

    await sensorService.stop();
    await sensorService.dispose();

    _kneeMotionProcessor?.reset();
    _kneeMotionProcessor = null;

    _imuSignalProcessor.reset();

    await _changeController.close();
  }
}

class ScreeningSessionState {
  bool hasChairStand = false;
  bool hasFastWalk = false;

  void reset() {
    hasChairStand = false;
    hasFastWalk = false;
  }
}

class TestQualityResult {
  final double score;
  final String label;

  final int sampleCount;
  final double durationSeconds;
  final double samplingRate;

  final double sampleCoverage;
  final double timestampRegularity;
  final double signalQuality;
  final double movementPresence;

  const TestQualityResult({
    required this.score,
    required this.label,
    required this.sampleCount,
    required this.durationSeconds,
    required this.samplingRate,
    required this.sampleCoverage,
    required this.timestampRegularity,
    required this.signalQuality,
    required this.movementPresence,
  });

  bool get isGood =>
      score >= 85;

  bool get isAcceptable =>
      score >= 70;

  bool get needsRepeat =>
      score < 70;

  String get summary {
    if (score >= 85) {
      return 'Sensor data and movement recording quality are good.';
    }

    if (score >= 70) {
      return 'Recording quality is acceptable for this test.';
    }

    if (score >= 50) {
      return 'Some recording-quality limitations were detected.';
    }

    return 'Recording quality is poor and the test may need to be repeated.';
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'label': label,
      'sample_count': sampleCount,
      'duration_seconds': durationSeconds,
      'sampling_rate': samplingRate,
      'sample_coverage': sampleCoverage,
      'timestamp_regularity': timestampRegularity,
      'signal_quality': signalQuality,
      'movement_presence': movementPresence,
    };
  }
}