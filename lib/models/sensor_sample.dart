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
    final rawTs = json['ts'] ?? json['timestamp'] ?? 0;
    final thighJson = json['thigh'];
    final shinJson = json['shin'];
    return SensorSample(
      timestamp: (rawTs is num) ? rawTs.toInt() : 0,
      thigh: thighJson is Map
          ? ImuData.fromJson(Map<String, dynamic>.from(thighJson))
          : const ImuData(ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0),
      shin: shinJson is Map
          ? ImuData.fromJson(Map<String, dynamic>.from(shinJson))
          : const ImuData(ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0),
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