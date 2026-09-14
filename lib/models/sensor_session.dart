import 'sensor_sample.dart';

class SensorSession {
  final String sessionId;
  final String patientId;
  final String testType;

  final int startTime;
  int? endTime;

  final double samplingRate;

  final List<SensorSample> samples;

  SensorSession({
    required this.sessionId,
    required this.patientId,
    required this.testType,
    required this.startTime,
    required this.samplingRate,
    List<SensorSample>? samples,
  }) : samples = samples ?? [];

  void addSample(SensorSample sample) {
    samples.add(sample);
  }

  void finish() {
    endTime = DateTime.now().millisecondsSinceEpoch;
  }

  int get sampleCount => samples.length;

  double get durationSeconds {
    if (samples.length < 2) {
      return 0;
    }

    return (samples.last.timestamp -
            samples.first.timestamp) /
        1000.0;
  }
}