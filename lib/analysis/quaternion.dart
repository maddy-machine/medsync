import 'dart:math';

class Quaternion {
  final double w;
  final double x;
  final double y;
  final double z;

  const Quaternion(
    this.w,
    this.x,
    this.y,
    this.z,
  );

  // Supports both:
  // Quaternion.identity
  // const Quaternion.identity
  const Quaternion.identity()
      : w = 1.0,
        x = 0.0,
        y = 0.0,
        z = 0.0;

  double get norm {
    return sqrt(
      w * w +
          x * x +
          y * y +
          z * z,
    );
  }

  Quaternion normalized() {
    final n = norm;

    if (n == 0) {
      return const Quaternion.identity();
    }

    return Quaternion(
      w / n,
      x / n,
      y / n,
      z / n,
    );
  }

  Quaternion conjugate() {
    return Quaternion(
      w,
      -x,
      -y,
      -z,
    );
  }

  Quaternion inverse() {
    final squaredNorm =
        w * w +
            x * x +
            y * y +
            z * z;

    if (squaredNorm == 0) {
      return const Quaternion.identity();
    }

    final c = conjugate();

    return Quaternion(
      c.w / squaredNorm,
      c.x / squaredNorm,
      c.y / squaredNorm,
      c.z / squaredNorm,
    );
  }

  Quaternion multiply(Quaternion other) {
    return Quaternion(
      w * other.w -
          x * other.x -
          y * other.y -
          z * other.z,
      w * other.x +
          x * other.w +
          y * other.z -
          z * other.y,
      w * other.y -
          x * other.z +
          y * other.w +
          z * other.x,
      w * other.z +
          x * other.y -
          y * other.x +
          z * other.w,
    );
  }

  Quaternion operator *(Quaternion other) {
    return multiply(other);
  }

  Quaternion scale(double value) {
    return Quaternion(
      w * value,
      x * value,
      y * value,
      z * value,
    );
  }

  Quaternion integrateGyroscope({
    required double gx,
    required double gy,
    required double gz,
    required double dt,
  }) {
    if (dt <= 0) {
      return this;
    }

    final omega = Quaternion(
      0,
      gx,
      gy,
      gz,
    );

    final derivative = multiply(omega);

    final next = Quaternion(
      w + 0.5 * derivative.w * dt,
      x + 0.5 * derivative.x * dt,
      y + 0.5 * derivative.y * dt,
      z + 0.5 * derivative.z * dt,
    );

    return next.normalized();
  }

  Vector3 rotate(Vector3 vector) {
    final vectorQuaternion = Quaternion(
      0,
      vector.x,
      vector.y,
      vector.z,
    );

    final result = multiply(vectorQuaternion)
        .multiply(inverse());

    return Vector3(
      result.x,
      result.y,
      result.z,
    );
  }

  Vector3 gravityDirectionBody() {
    return rotate(
      const Vector3(0, 0, 1),
    );
  }

  double relativePitchTo(Quaternion other) {
    final relative =
        inverse().multiply(other);

    final sinPitch =
        2 *
        (
          relative.w * relative.y -
              relative.z * relative.x
        );

    final cosPitch =
        1 -
        2 *
        (
          relative.y * relative.y +
              relative.x * relative.x
        );

    return atan2(
      sinPitch,
      cosPitch,
    );
  }
}

class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(
    this.x,
    this.y,
    this.z,
  );

  double get magnitude {
    return sqrt(
      x * x +
          y * y +
          z * z,
    );
  }

  Vector3 normalized() {
    final magnitude = this.magnitude;

    if (magnitude == 0) {
      return const Vector3(0, 0, 0);
    }

    return Vector3(
      x / magnitude,
      y / magnitude,
      z / magnitude,
    );
  }

  double dot(Vector3 other) {
    return x * other.x +
        y * other.y +
        z * other.z;
  }

  Vector3 operator -(Vector3 other) {
    return Vector3(
      x - other.x,
      y - other.y,
      z - other.z,
    );
  }

  Vector3 operator +(Vector3 other) {
    return Vector3(
      x + other.x,
      y + other.y,
      z + other.z,
    );
  }

  Vector3 operator *(double value) {
    return Vector3(
      x * value,
      y * value,
      z * value,
    );
  }
}