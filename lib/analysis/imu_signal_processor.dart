import 'package:flutter/foundation.dart';

import '../models/imu_data.dart';
import '../models/sensor_sample.dart';

class ImuSignalProcessor {
  final double emaAlpha;

  double _thighGxBias = 0.0;
  double _thighGyBias = 0.0;
  double _thighGzBias = 0.0;

  double _shinGxBias = 0.0;
  double _shinGyBias = 0.0;
  double _shinGzBias = 0.0;

  bool _calibrated = false;

  ImuData? _previousThigh;
  ImuData? _previousShin;

  final List<double> _thighGxCalibration = [];
  final List<double> _thighGyCalibration = [];
  final List<double> _thighGzCalibration = [];

  final List<double> _shinGxCalibration = [];
  final List<double> _shinGyCalibration = [];
  final List<double> _shinGzCalibration = [];

  ImuSignalProcessor({
    this.emaAlpha = 0.25,
  }) : assert(
          emaAlpha > 0 && emaAlpha <= 1,
          'EMA alpha must be between 0 and 1.',
        );

  bool get isCalibrated => _calibrated;

  double get thighGxBias => _thighGxBias;
  double get thighGyBias => _thighGyBias;
  double get thighGzBias => _thighGzBias;

  double get shinGxBias => _shinGxBias;
  double get shinGyBias => _shinGyBias;
  double get shinGzBias => _shinGzBias;

  void startCalibration() {
    _calibrated = false;

    _thighGxCalibration.clear();
    _thighGyCalibration.clear();
    _thighGzCalibration.clear();

    _shinGxCalibration.clear();
    _shinGyCalibration.clear();
    _shinGzCalibration.clear();

    _previousThigh = null;
    _previousShin = null;
  }

  void addCalibrationSample(
    SensorSample sample,
  ) {
    if (_calibrated) {
      return;
    }

    _thighGxCalibration.add(sample.thigh.gx);
    _thighGyCalibration.add(sample.thigh.gy);
    _thighGzCalibration.add(sample.thigh.gz);

    _shinGxCalibration.add(sample.shin.gx);
    _shinGyCalibration.add(sample.shin.gy);
    _shinGzCalibration.add(sample.shin.gz);
  }

  bool finishCalibration() {
    debugPrint('[MedSync] finishCalibration() called. Samples count: thigh=${_thighGxCalibration.length}, shin=${_shinGxCalibration.length}');
    if (_thighGxCalibration.isEmpty ||
        _shinGxCalibration.isEmpty) {
      return false;
    }

    _thighGxBias = _mean(_thighGxCalibration);
    _thighGyBias = _mean(_thighGyCalibration);
    _thighGzBias = _mean(_thighGzCalibration);

    _shinGxBias = _mean(_shinGxCalibration);
    _shinGyBias = _mean(_shinGyCalibration);
    _shinGzBias = _mean(_shinGzCalibration);

    _calibrated = true;

    _previousThigh = null;
    _previousShin = null;

    return true;
  }

  SensorSample process(
    SensorSample sample,
  ) {
    final thighGyroCorrected = ImuData(
      ax: sample.thigh.ax,
      ay: sample.thigh.ay,
      az: sample.thigh.az,
      gx: sample.thigh.gx - _thighGxBias,
      gy: sample.thigh.gy - _thighGyBias,
      gz: sample.thigh.gz - _thighGzBias,
    );

    final shinGyroCorrected = ImuData(
      ax: sample.shin.ax,
      ay: sample.shin.ay,
      az: sample.shin.az,
      gx: sample.shin.gx - _shinGxBias,
      gy: sample.shin.gy - _shinGyBias,
      gz: sample.shin.gz - _shinGzBias,
    );

    final filteredThigh =
        _applyEma(
      current: thighGyroCorrected,
      previous: _previousThigh,
    );

    final filteredShin =
        _applyEma(
      current: shinGyroCorrected,
      previous: _previousShin,
    );

    _previousThigh = filteredThigh;
    _previousShin = filteredShin;

    return SensorSample(
      timestamp: sample.timestamp,
      thigh: filteredThigh,
      shin: filteredShin,
    );
  }

  void reset() {
    _thighGxBias = 0.0;
    _thighGyBias = 0.0;
    _thighGzBias = 0.0;

    _shinGxBias = 0.0;
    _shinGyBias = 0.0;
    _shinGzBias = 0.0;

    _calibrated = false;

    _thighGxCalibration.clear();
    _thighGyCalibration.clear();
    _thighGzCalibration.clear();

    _shinGxCalibration.clear();
    _shinGyCalibration.clear();
    _shinGzCalibration.clear();

    _previousThigh = null;
    _previousShin = null;
  }

  ImuData _applyEma({
    required ImuData current,
    required ImuData? previous,
  }) {
    if (previous == null) {
      return current;
    }

    return ImuData(
      ax: _ema(
        current.ax,
        previous.ax,
      ),
      ay: _ema(
        current.ay,
        previous.ay,
      ),
      az: _ema(
        current.az,
        previous.az,
      ),
      gx: _ema(
        current.gx,
        previous.gx,
      ),
      gy: _ema(
        current.gy,
        previous.gy,
      ),
      gz: _ema(
        current.gz,
        previous.gz,
      ),
    );
  }

  double _ema(
    double current,
    double previous,
  ) {
    return emaAlpha * current +
        (1.0 - emaAlpha) * previous;
  }

  double _mean(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return 0.0;
    }

    double sum = 0.0;

    for (final value in values) {
      sum += value;
    }

    return sum / values.length;
  }
}