import 'dart:async';
import 'dart:math';

import '../models/imu_data.dart';
import '../models/sensor_sample.dart';
import 'sensor_service.dart';

class MockSensorService implements SensorService {
  final StreamController<SensorSample>
      _sampleController =
      StreamController<SensorSample>.broadcast();

  Timer? _timer;

  bool _isRunning = false;

  int _timestamp = 0;

  double _phase = 0.0;

  @override
  Stream<SensorSample> get sampleStream =>
      _sampleController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    _timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) {
        if (!_isRunning ||
            _sampleController.isClosed) {
          return;
        }

        _timestamp += 10;

        _phase += 0.12;

        final shinMotion =
            sin(_phase);

        final thighMotion =
            sin(_phase * 0.5);

        final sample = SensorSample(
          timestamp: _timestamp,
          thigh: ImuData(
            ax: 0.35 * thighMotion,
            ay: 0.20 * cos(_phase),
            az: 9.81 +
                0.25 * sin(_phase * 2),
            gx: 0.4 * thighMotion,
            gy: 0.3 * cos(_phase),
            gz: 0.2 * sin(_phase * 0.7),
          ),
          shin: ImuData(
            ax: 0.55 * shinMotion,
            ay: 0.30 * cos(_phase),
            az: 9.81 +
                0.45 * sin(_phase * 2),
            gx: 1.2 * shinMotion,
            gy: 0.8 * cos(_phase),
            gz: 0.5 * sin(_phase * 0.8),
          ),
        );

        _sampleController.add(sample);
      },
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    _isRunning = false;
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;

    _isRunning = false;

    await _sampleController.close();
  }
}