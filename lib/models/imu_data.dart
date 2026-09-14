class ImuData {
  final double ax;
  final double ay;
  final double az;

  final double gx;
  final double gy;
  final double gz;

  const ImuData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  factory ImuData.fromJson(Map<String, dynamic> json) {
    return ImuData(
      ax: (json['ax'] as num?)?.toDouble() ?? 0.0,
      ay: (json['ay'] as num?)?.toDouble() ?? 0.0,
      az: (json['az'] as num?)?.toDouble() ?? 0.0,
      gx: (json['gx'] as num?)?.toDouble() ?? 0.0,
      gy: (json['gy'] as num?)?.toDouble() ?? 0.0,
      gz: (json['gz'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ax': ax,
      'ay': ay,
      'az': az,
      'gx': gx,
      'gy': gy,
      'gz': gz,
    };
  }
}