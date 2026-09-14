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
      ax: (json['ax'] as num).toDouble(),
      ay: (json['ay'] as num).toDouble(),
      az: (json['az'] as num).toDouble(),
      gx: (json['gx'] as num).toDouble(),
      gy: (json['gy'] as num).toDouble(),
      gz: (json['gz'] as num).toDouble(),
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