import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/camera_vision_result.dart';
import '../models/patient_assessment.dart';
import '../models/screening_result.dart';
import '../services/camera_service.dart';
import '../services/camera_vision_inference_service.dart';
import '../widgets/camera_pose_overlay.dart';

/// Phase of the Camera Vision Test Screen.
enum CameraTestPhase {
  requestingPermission,
  permissionDenied,
  readyToRecord,
  countdown,
  recording,
  processing,
  completed,
}

/// Comprehensive camera vision screening test screen that records patient movement,
/// overlays real-time AI skeletal guides, and feeds video into the vision inference pipeline.
class CameraVisionTestScreen extends StatefulWidget {
  final PatientAssessment patientAssessment;
  final CameraVisionInferenceService inferenceService;
  final CameraService? cameraService;

  const CameraVisionTestScreen({
    super.key,
    required this.patientAssessment,
    this.inferenceService = const StubCameraVisionInferenceService(),
    this.cameraService,
  });

  @override
  State<CameraVisionTestScreen> createState() => _CameraVisionTestScreenState();
}

class _CameraVisionTestScreenState extends State<CameraVisionTestScreen> {
  late final CameraService _cameraService;
  CameraTestPhase _phase = CameraTestPhase.requestingPermission;

  int _countdownSeconds = 3;
  int _recordingSecondsRemaining = 10;
  Timer? _timer;

  CameraVisionResult? _result;
  String? _capturedVideoPath;
  String _processingStepText = 'Extracting 3D Pose Landmarks...';

  @override
  void initState() {
    super.initState();
    _cameraService = widget.cameraService ?? CameraService();
    _checkPermissionAndInitCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInitCamera() async {
    setState(() => _phase = CameraTestPhase.requestingPermission);

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _phase = CameraTestPhase.permissionDenied);
      }
      return;
    }

    final success = await _cameraService.initialize();
    if (!mounted) return;

    if (success) {
      setState(() => _phase = CameraTestPhase.readyToRecord);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cameraService.errorMessage ?? 'Failed to access camera.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _phase = CameraTestPhase.permissionDenied);
    }
  }

  void _startCountdown() {
    setState(() {
      _phase = CameraTestPhase.countdown;
      _countdownSeconds = 3;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    final started = await _cameraService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cameraService.errorMessage ?? 'Could not start recording.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() => _phase = CameraTestPhase.readyToRecord);
      }
      return;
    }

    setState(() {
      _phase = CameraTestPhase.recording;
      _recordingSecondsRemaining = 10;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_recordingSecondsRemaining > 1) {
        setState(() => _recordingSecondsRemaining--);
      } else {
        timer.cancel();
        _stopRecordingAndAnalyze();
      }
    });
  }

  Future<void> _stopRecordingAndAnalyze() async {
    _timer?.cancel();
    setState(() {
      _phase = CameraTestPhase.processing;
      _processingStepText = 'Extracting 3D Pose Landmarks...';
    });

    final recordedFile = await _cameraService.stopRecording();
    _capturedVideoPath = recordedFile?.path ?? 'session_movement_video.mp4';

    if (!mounted) return;

    _animateProcessingSteps();

    try {
      final analysisResult = await widget.inferenceService.analyzeVideo(
        videoPath: _capturedVideoPath!,
        patientAssessment: widget.patientAssessment,
      );

      if (!mounted) return;
      setState(() {
        _result = analysisResult;
        _phase = CameraTestPhase.completed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing video kinematics: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _phase = CameraTestPhase.readyToRecord);
    }
  }

  void _animateProcessingSteps() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _phase == CameraTestPhase.processing) {
        setState(() => _processingStepText = 'Calculating Knee Flexion & Gait Symmetry...');
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _phase == CameraTestPhase.processing) {
        setState(() => _processingStepText = 'Synthesizing Kinematic Risk Assessment...');
      }
    });
  }

  void _retakeTest() {
    setState(() {
      _result = null;
      _phase = CameraTestPhase.readyToRecord;
    });
  }

  void _finishAndSave() {
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        elevation: 0,
        title: const Text(
          'Vision Movement Screening',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(_result),
        ),
        actions: [
          if (_phase == CameraTestPhase.readyToRecord)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              tooltip: 'Switch Camera',
              onPressed: () async {
                await _cameraService.switchCamera();
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Layer 1: Camera Viewfinder / Preview
            _buildCameraLayer(),

            // Layer 2: AR Pose Overlay
            if (_phase == CameraTestPhase.readyToRecord ||
                _phase == CameraTestPhase.countdown ||
                _phase == CameraTestPhase.recording ||
                _phase == CameraTestPhase.processing)
              CameraPoseOverlay(
                mode: _phase == CameraTestPhase.recording
                    ? PoseOverlayMode.recording
                    : _phase == CameraTestPhase.processing
                        ? PoseOverlayMode.processing
                        : PoseOverlayMode.aligning,
              ),

            // Layer 3: Interactive Phase UI
            _buildPhaseOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_phase == CameraTestPhase.permissionDenied ||
        _phase == CameraTestPhase.requestingPermission) {
      return Container(color: const Color(0xFF0F172A));
    }

    if (_cameraService.controller != null &&
        _cameraService.controller!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraService.controller!.value.previewSize?.height ?? 1,
            height: _cameraService.controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraService.controller!),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
      ),
    );
  }

  Widget _buildPhaseOverlay(ThemeData theme) {
    switch (_phase) {
      case CameraTestPhase.requestingPermission:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        );

      case CameraTestPhase.permissionDenied:
        return _buildPermissionDeniedView();

      case CameraTestPhase.readyToRecord:
        return _buildReadyToRecordView();

      case CameraTestPhase.countdown:
        return _buildCountdownView();

      case CameraTestPhase.recording:
        return _buildRecordingView();

      case CameraTestPhase.processing:
        return _buildProcessingView();

      case CameraTestPhase.completed:
        return _buildCompletedResultsView(theme);
    }
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Color(0xFFF87171),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vision screening uses your device camera to track posture, bilateral symmetry, and knee kinematics during movement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _checkPermissionAndInitCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Allow Camera Permission'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Skip Vision Screening for Now',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyToRecordView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Step back 2–3 meters so your full body is visible inside the frame.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '10-Second Movement Test',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Stand up, walk in place, or perform gentle knee bends',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _startCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.fiber_manual_record, color: Color(0xFFF87171)),
                  label: const Text(
                    'Start Recording Movement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownView() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF38BDF8), width: 3),
        ),
        child: Center(
          child: Text(
            '$_countdownSeconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingView() {
    final progress = (10 - _recordingSecondsRemaining) / 10.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '00:0${_recordingSecondsRemaining}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _stopRecordingAndAnalyze,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.stop),
                  label: const Text('Finish Early & Analyze'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Vision Analysis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _processingStepText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedResultsView(ThemeData theme) {
    final res = _result;
    if (res == null) return const SizedBox.shrink();

    final riskColor = res.riskLevel == ScreeningRiskLevel.higher
        ? const Color(0xFFEF4444)
        : res.riskLevel == ScreeningRiskLevel.moderate
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      color: const Color(0xFF0F172A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined, color: Color(0xFF38BDF8), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model Training In Progress',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Using synthetic vision inference pipeline while real deep learning dataset training is completing.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  riskColor.withValues(alpha: 0.18),
                  const Color(0xFF1E293B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vision Kinematic Risk',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: riskColor),
                      ),
                      child: Text(
                        res.riskLabel,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      res.postureScore.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '/ 100\nPosture Index',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard(
                title: 'Bilateral Symmetry',
                value: '${(res.gaitSymmetryIndex * 100).toStringAsFixed(1)}%',
                icon: Icons.balance,
                iconColor: const Color(0xFF38BDF8),
                caption: 'Left vs. Right motion match',
              ),
              _buildMetricCard(
                title: 'Knee Flexion',
                value: '${res.kneeFlexionAngleDeg.toStringAsFixed(1)}°',
                icon: Icons.straighten,
                iconColor: const Color(0xFF34D399),
                caption: 'Peak dynamic joint angle',
              ),
              _buildMetricCard(
                title: 'Step Cadence',
                value: res.stepCadence.toStringAsFixed(0),
                unit: ' spm',
                icon: Icons.directions_walk,
                iconColor: const Color(0xFFFBBF24),
                caption: 'Paced walking frequency',
              ),
              _buildMetricCard(
                title: 'Antalgic Gait',
                value: res.antalgicGaitScore.toStringAsFixed(1),
                unit: ' / 100',
                icon: Icons.health_and_safety_outlined,
                iconColor: const Color(0xFFA78BFA),
                caption: 'Limp compensation level',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (res.kinematicFindings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kinematic Observations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...res.kinematicFindings.map(
                    (finding) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16)),
                          Expanded(
                            child: Text(
                              finding,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retakeTest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retake Test'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _finishAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save & Continue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    required Color iconColor,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
