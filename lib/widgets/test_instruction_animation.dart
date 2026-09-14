import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/movement_test.dart';

class TestInstructionAnimation extends StatefulWidget {
  final MovementTestType type;

  const TestInstructionAnimation({
    super.key,
    required this.type,
  });

  @override
  State<TestInstructionAnimation> createState() =>
      _TestInstructionAnimationState();
}

class _TestInstructionAnimationState
    extends State<TestInstructionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (widget.type == MovementTestType.chairStand) {
          return _ChairStandAnimation(
            progress: _animationController.value,
          );
        }

        return _FastWalkAnimation(
          progress: _animationController.value,
        );
      },
    );
  }
}

class _ChairStandAnimation extends StatelessWidget {
  final double progress;

  const _ChairStandAnimation({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final movement =
        (math.sin(progress * math.pi * 2) + 1) / 2;

    final eased =
        Curves.easeInOut.transform(movement);

    return Container(
      color: colors.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: colors.primary,
              ),
            ),
          ),

          Positioned(
            left: 22,
            top: 18,
            child: _Badge(
              icon: Icons.swap_vert_rounded,
              text: 'SIT  ↕  STAND',
              color: colors.primary,
            ),
          ),

          Positioned(
            right: 20,
            top: 21,
            child: Text(
              '30 SEC',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),

          Positioned(
            left: 24,
            bottom: 25,
            child: SizedBox(
              width: 78,
              height: 115,
              child: CustomPaint(
                painter: _ChairPainter(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 20,
              ),
              child: Transform.translate(
                offset: Offset(
                  25 * (1 - eased),
                  38 * (1 - eased),
                ),
                child: CustomPaint(
                  size: const Size(80, 150),
                  painter: _PersonPainter(
                    primary: colors.primary,
                    secondary:
                        colors.primaryContainer,
                    kneeBend: 1 - eased,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 12,
            right: 20,
            child: Text(
              eased > 0.5
                  ? 'STAND'
                  : 'SIT',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FastWalkAnimation extends StatelessWidget {
  final double progress;

  const _FastWalkAnimation({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final walkProgress =
        Curves.easeInOut.transform(progress);

    final legMovement =
        math.sin(progress * math.pi * 8);

    return Container(
      color: colors.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: colors.primary,
              ),
            ),
          ),

          Positioned(
            left: 20,
            top: 18,
            child: _Badge(
              icon: Icons.directions_walk_rounded,
              text: 'FAST WALK',
              color: colors.primary,
            ),
          ),

          Positioned(
            left: 22,
            right: 22,
            bottom: 42,
            child: CustomPaint(
              size: const Size(
                double.infinity,
                20,
              ),
              painter: _DistancePainter(
                color: colors.primary,
              ),
            ),
          ),

          Positioned(
            left: 22,
            bottom: 13,
            child: Text(
              'START',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Positioned(
            right: 22,
            bottom: 13,
            child: Text(
              '20 m',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Align(
            alignment: Alignment(
              -0.82 + (walkProgress * 1.64),
              0.02,
            ),
            child: Transform.translate(
              offset: Offset(
                0,
                legMovement * 2,
              ),
              child: CustomPaint(
                size: const Size(76, 145),
                painter: _PersonPainter(
                  primary: colors.primary,
                  secondary:
                      colors.primaryContainer,
                  kneeBend: 0.15,
                  legSwing:
                      legMovement * 0.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Badge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  const _GridPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    for (
      double x = 0;
      x < size.width;
      x += 28
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (
      double y = 0;
      y < size.height;
      y += 28
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _GridPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

class _DistancePainter extends CustomPainter {
  final Color color;

  const _DistancePainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dash = 7.0;
    const gap = 6.0;

    var x = 0.0;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(
          math.min(
            x + dash,
            size.width,
          ),
          size.height / 2,
        ),
        paint,
      );

      x += dash + gap;
    }

    final arrow = Path()
      ..moveTo(
        size.width - 10,
        size.height / 2 - 5,
      )
      ..lineTo(
        size.width,
        size.height / 2,
      )
      ..lineTo(
        size.width - 10,
        size.height / 2 + 5,
      );

    canvas.drawPath(
      arrow,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _DistancePainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

class _ChairPainter extends CustomPainter {
  final Color color;

  const _ChairPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(14, 38),
      Offset(62, 38),
      paint,
    );

    canvas.drawLine(
      Offset(14, 38),
      Offset(14, 92),
      paint,
    );

    canvas.drawLine(
      Offset(62, 38),
      Offset(62, 92),
      paint,
    );

    canvas.drawLine(
      Offset(14, 92),
      Offset(6, 108),
      paint,
    );

    canvas.drawLine(
      Offset(62, 92),
      Offset(70, 108),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ChairPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

class _PersonPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final double kneeBend;
  final double legSwing;

  const _PersonPainter({
    required this.primary,
    required this.secondary,
    required this.kneeBend,
    this.legSwing = 0,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final centerX = size.width / 2;

    final skinPaint = Paint()
      ..color = secondary;

    final bodyPaint = Paint()
      ..color = primary;

    final linePaint = Paint()
      ..color = primary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(centerX, 18),
      11,
      skinPaint,
    );

    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          centerX,
          56,
        ),
        width: 29,
        height: 52,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      torso,
      bodyPaint,
    );

    canvas.drawLine(
      Offset(centerX - 13, 47),
      Offset(centerX - 27, 76),
      linePaint,
    );

    canvas.drawLine(
      Offset(centerX + 13, 47),
      Offset(centerX + 27, 76),
      linePaint,
    );

    final bend =
        kneeBend.clamp(0.0, 1.0);

    final leftHip =
        Offset(centerX - 8, 82);

    final leftKnee = Offset(
      centerX - 12 -
          (bend * 11) +
          legSwing * 12,
      111,
    );

    final leftFoot = Offset(
      centerX - 18 +
          (bend * 8) +
          legSwing * 17,
      138,
    );

    canvas.drawLine(
      leftHip,
      leftKnee,
      linePaint,
    );

    canvas.drawLine(
      leftKnee,
      leftFoot,
      linePaint,
    );

    final rightHip =
        Offset(centerX + 8, 82);

    final rightKnee = Offset(
      centerX + 12 +
          (bend * 11) -
          legSwing * 12,
      111,
    );

    final rightFoot = Offset(
      centerX + 18 -
          (bend * 8) -
          legSwing * 17,
      138,
    );

    canvas.drawLine(
      rightHip,
      rightKnee,
      linePaint,
    );

    canvas.drawLine(
      rightKnee,
      rightFoot,
      linePaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PersonPainter oldDelegate,
  ) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.kneeBend != kneeBend ||
        oldDelegate.legSwing != legSwing;
  }
}