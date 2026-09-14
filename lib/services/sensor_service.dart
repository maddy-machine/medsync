import '../models/sensor_sample.dart';

abstract class SensorService {
  Stream<SensorSample> get sampleStream;

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();

  bool get isRunning;
}