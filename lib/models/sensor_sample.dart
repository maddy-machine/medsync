import 'imu_data.dart';

class SensorSample {
  final int timestamp;

  final ImuData thigh;
  final ImuData shin;

  const SensorSample({
    required this.timestamp,
    required this.thigh,
    required this.shin,
  });

  factory SensorSample.fromJson(Map<String, dynamic> json) {
    // The ESP32 firmware sends "ts"; accept both "ts" and
    // "timestamp" so the model works with both the hardware
    // and any previously serialized data.
    final rawTs = json['ts'] ?? json['timestamp'];
    return SensorSample(
      timestamp: (rawTs as num).toInt(),
      thigh: ImuData.fromJson(
        Map<String, dynamic>.from(json['thigh']),
      ),
      shin: ImuData.fromJson(
        Map<String, dynamic>.from(json['shin']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'thigh': thigh.toJson(),
      'shin': shin.toJson(),
    };
  }
}