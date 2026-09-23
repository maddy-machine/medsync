import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service that encapsulates camera discovery, initialization,
/// streaming preview, and video recording for movement vision screening.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _isRecording;
  String? get errorMessage => _errorMessage;
  List<CameraDescription> get discoveredCameras => _cameras;

  /// Initializes the device camera. Prefers the back camera with medium resolution.
  Future<bool> initialize({CameraLensDirection preferredDirection = CameraLensDirection.back}) async {
    try {
      _errorMessage = null;
      _cameras = await availableCamerasList();
      if (_cameras.isEmpty) {
        _errorMessage = 'No camera found on this device.';
        return false;
      }

      CameraDescription selectedCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == preferredDirection,
        orElse: () => _cameras.first,
      );

      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await newController.initialize();
      _controller = newController;
      return true;
    } on CameraException catch (e) {
      _errorMessage = 'Camera initialization failed: ${e.description ?? e.code}';
      debugPrint('[CameraService] Error: $_errorMessage');
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected camera error: $e';
      debugPrint('[CameraService] Error: $_errorMessage');
      return false;
    }
  }

  /// Discovers available cameras on the device.
  @visibleForTesting
  Future<List<CameraDescription>> availableCamerasList() async {
    try {
      return await availableCameras();
    } catch (e) {
      debugPrint('[CameraService] Error fetching cameras: $e');
      return [];
    }
  }

  /// Starts video recording.
  Future<bool> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Camera is not initialized.';
      return false;
    }
    if (_controller!.value.isRecordingVideo) {
      return true;
    }

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      return true;
    } on CameraException catch (e) {
      _errorMessage = 'Could not start recording: ${e.description ?? e.code}';
      debugPrint('[CameraService] Recording error: $_errorMessage');
      return false;
    }
  }

  /// Stops video recording and returns the recorded video file.
  Future<XFile?> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      _isRecording = false;
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      _isRecording = false;
      return file;
    } on CameraException catch (e) {
      _errorMessage = 'Could not stop recording: ${e.description ?? e.code}';
      debugPrint('[CameraService] Stop recording error: $_errorMessage');
      _isRecording = false;
      return null;
    }
  }

  /// Toggles between front and back camera if multiple cameras exist.
  Future<bool> switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return false;

    final currentDirection = _controller!.description.lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await dispose();
    return await initialize(preferredDirection: targetDirection);
  }

  /// Disposes camera resources.
  Future<void> dispose() async {
    try {
      if (_controller != null) {
        if (_controller!.value.isRecordingVideo) {
          await _controller!.stopVideoRecording();
        }
        await _controller!.dispose();
        _controller = null;
      }
    } catch (e) {
      debugPrint('[CameraService] Error disposing camera: $e');
    } finally {
      _isRecording = false;
    }
  }
}
