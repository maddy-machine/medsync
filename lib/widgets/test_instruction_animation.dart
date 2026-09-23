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
      duration: const Duration(milliseconds: 3200),
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
        } else if (widget.type == MovementTestType.fastWalk) {
          return _FastWalkAnimation(
            progress: _animationController.value,
          );
        }

        return _CameraVisionAnimation(
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

    // Smooth sit-to-stand motion cycle using sin curve with pause at top & bottom
    final rawPhase = math.sin(progress * math.pi * 2);
    final eased = Curves.easeInOutCubic.transform((rawPhase + 1) / 2);

    final angle = (90 + (eased * 85)).round(); // 90° seated -> 175° standing
    final isStanding = eased > 0.5;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Background Alignment Grid
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: colors.primary,
              ),
            ),
          ),

          // Header Badge
          Positioned(
            left: 14,
            top: 12,
            child: _Badge(
              icon: Icons.event_seat_rounded,
              text: 'SIT-TO-STAND (30S)',
              color: colors.primary,
            ),
          ),

          // Angle Readout Badge
          Positioned(
            right: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'KNEE $angle°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),

          // Floor Line
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Container(
              height: 2,
              color: colors.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),

          // Integrated Chair & Person Anatomy Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _SitToStandBiomechanicsPainter(
                standProgress: eased,
                primaryColor: colors.primary,
                accentColor: colors.secondary,
                chairColor: colors.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),

          // State Label (Sit vs Stand)
          Positioned(
            bottom: 10,
            right: 14,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isStanding
                    ? const Color(0xFF10B981)
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isStanding ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: isStanding ? Colors.white : colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isStanding ? 'STAND (EXTENSION)' : 'SIT (FLEXION)',
                    style: TextStyle(
                      color: isStanding ? Colors.white : colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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

    final walkProgress = Curves.easeInOut.transform(progress);
    final legMovement = math.sin(progress * math.pi * 8);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
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
            left: 14,
            top: 12,
            child: _Badge(
              icon: Icons.directions_walk_rounded,
              text: 'FAST WALK (20M)',
              color: colors.primary,
            ),
          ),

          Positioned(
            right: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'GAIT PACING',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 38,
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: _DistancePainter(
                color: colors.primary,
              ),
            ),
          ),

          Positioned(
            left: 20,
            bottom: 10,
            child: Text(
              'START (0m)',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Positioned(
            right: 20,
            bottom: 10,
            child: Text(
              'FINISH (20m)',
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
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
              offset: Offset(0, legMovement * 2.5),
              child: CustomPaint(
                size: const Size(76, 145),
                painter: _PersonGaitPainter(
                  primary: colors.primary,
                  secondary: colors.primaryContainer,
                  kneeBend: 0.15,
                  legSwing: legMovement * 0.25,
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
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
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
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DistancePainter extends CustomPainter {
  final Color color;

  const _DistancePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
        Offset(math.min(x + dash, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }

    final arrow = Path()
      ..moveTo(size.width - 10, size.height / 2 - 5)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 10, size.height / 2 + 5);

    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(covariant _DistancePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Clinically accurate custom painter for Sit-to-Stand Biomechanics
class _SitToStandBiomechanicsPainter extends CustomPainter {
  final double standProgress; // 0.0 = fully seated, 1.0 = fully standing
  final Color primaryColor;
  final Color accentColor;
  final Color chairColor;

  const _SitToStandBiomechanicsPainter({
    required this.standProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.chairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height - 24;

    // Chair geometry parameters
    final chairCenterX = size.width * 0.46;
    const seatWidth = 56.0;
    final seatY = floorY - 44.0;
    const backrestHeight = 58.0;

    // -------------------------------------------------------------
    // 1. DRAW CHAIR (Backrest, Cushion, Legs with Depth Shading)
    // -------------------------------------------------------------
    final chairFramePaint = Paint()
      ..color = chairColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final chairCushionPaint = Paint()
      ..color = chairColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Chair Seat Cushion
    final seatRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        chairCenterX - seatWidth / 2,
        seatY - 6,
        chairCenterX + seatWidth / 2,
        seatY + 4,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(seatRect, chairCushionPaint);
    canvas.drawRRect(seatRect, chairFramePaint);

    // Chair Backrest
    final backrestPath = Path()
      ..moveTo(chairCenterX - seatWidth / 2 + 4, seatY)
      ..lineTo(chairCenterX - seatWidth / 2 + 4, seatY - backrestHeight)
      ..lineTo(chairCenterX - seatWidth / 2 + 18, seatY - backrestHeight);
    canvas.drawPath(backrestPath, chairFramePaint);

    // Chair Legs (Front & Rear)
    canvas.drawLine(
      Offset(chairCenterX - seatWidth / 2 + 6, seatY),
      Offset(chairCenterX - seatWidth / 2 + 6, floorY),
      chairFramePaint,
    );
    canvas.drawLine(
      Offset(chairCenterX + seatWidth / 2 - 6, seatY),
      Offset(chairCenterX + seatWidth / 2 - 6, floorY),
      chairFramePaint,
    );

    // -------------------------------------------------------------
    // 2. BIOMECHANICAL ANATOMY COMPUTATION (Sit -> Stand)
    // -------------------------------------------------------------
    // Feet remain stationary on floor in front of chair
    final footX = chairCenterX + 16.0;
    final footY = floorY - 4.0;

    // Hip position moves from seat cushion up to standing position
    final seatedHipX = chairCenterX - 4.0;
    final seatedHipY = seatY - 8.0;

    final standingHipX = chairCenterX + 12.0;
    final standingHipY = floorY - 96.0;

    final hipX = seatedHipX + (standingHipX - seatedHipX) * standProgress;
    final hipY = seatedHipY + (standingHipY - seatedHipY) * standProgress;

    // Knee position calculates realistic flexion/extension
    final seatedKneeX = footX;
    final seatedKneeY = seatY - 4.0;

    final standingKneeX = chairCenterX + 14.0;
    final standingKneeY = floorY - 50.0;

    final kneeX = seatedKneeX + (standingKneeX - seatedKneeX) * standProgress;
    final kneeY = seatedKneeY + (standingKneeY - seatedKneeY) * standProgress;

    final hip = Offset(hipX, hipY);
    final knee = Offset(kneeX, kneeY);
    final ankle = Offset(footX, footY);
    final footEnd = Offset(footX + 16.0, footY);

    // Spine and Head
    final leanAngle = (1.0 - standProgress) * 0.18; // Lean slightly forward when rising
    final shoulderX = hipX + math.sin(leanAngle) * 44;
    final shoulderY = hipY - math.cos(leanAngle) * 44;
    final shoulder = Offset(shoulderX, shoulderY);

    final headX = shoulderX + math.sin(leanAngle) * 18;
    final headY = shoulderY - math.cos(leanAngle) * 18 - 10;
    final head = Offset(headX, headY);

    // -------------------------------------------------------------
    // 3. DRAW PERSON SKELETON & SEGMENTS
    // -------------------------------------------------------------
    final limbPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Draw Head
    canvas.drawCircle(head, 12, headPaint);

    // Draw Torso (Spine)
    canvas.drawLine(hip, shoulder, limbPaint);

    // Draw Crossed Arms over Chest
    final armCrossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final midTorsoX = (hip.dx + shoulder.dx) / 2;
    final midTorsoY = (hip.dy + shoulder.dy) / 2;
    canvas.drawLine(
      Offset(midTorsoX - 10, midTorsoY - 8),
      Offset(midTorsoX + 12, midTorsoY + 6),
      armCrossPaint,
    );
    canvas.drawLine(
      Offset(midTorsoX + 10, midTorsoY - 8),
      Offset(midTorsoX - 12, midTorsoY + 6),
      armCrossPaint,
    );

    // Draw Thigh Segment (Hip to Knee)
    canvas.drawLine(hip, knee, limbPaint);

    // Draw Shin Segment (Knee to Ankle)
    canvas.drawLine(knee, ankle, limbPaint);

    // Draw Foot
    canvas.drawLine(ankle, footEnd, limbPaint);

    // -------------------------------------------------------------
    // 4. DRAW DUAL-IMU SENSOR HIGH-VISIBILITY GLOW STRAPS
    // -------------------------------------------------------------
    final thighSensorPos = Offset(
      (hip.dx + knee.dx) / 2,
      (hip.dy + knee.dy) / 2,
    );
    final shinSensorPos = Offset(
      (knee.dx + ankle.dx) / 2,
      (knee.dy + ankle.dy) / 2,
    );

    final thighGlowPaint = Paint()
      ..color = const Color(0xFF10B981) // Green Thigh IMU 0x68
      ..style = PaintingStyle.fill;

    final shinGlowPaint = Paint()
      ..color = const Color(0xFF06B6D4) // Cyan Shin IMU 0x69
      ..style = PaintingStyle.fill;

    final sensorBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Thigh IMU (0x68)
    canvas.drawCircle(thighSensorPos, 7, thighGlowPaint);
    canvas.drawCircle(thighSensorPos, 7, sensorBorderPaint);

    // Shin IMU (0x69)
    canvas.drawCircle(shinSensorPos, 7, shinGlowPaint);
    canvas.drawCircle(shinSensorPos, 7, sensorBorderPaint);

    // -------------------------------------------------------------
    // 5. DRAW DYNAMIC KNEE JOINT ANGLE ARC & INDICATOR
    // -------------------------------------------------------------
    final arcPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(knee, 16, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SitToStandBiomechanicsPainter oldDelegate) {
    return oldDelegate.standProgress != standProgress ||
        oldDelegate.primaryColor != primaryColor;
  }
}

class _PersonGaitPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final double kneeBend;
  final double legSwing;

  const _PersonGaitPainter({
    required this.primary,
    required this.secondary,
    required this.kneeBend,
    this.legSwing = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final skinPaint = Paint()..color = secondary;
    final bodyPaint = Paint()..color = primary;

    final linePaint = Paint()
      ..color = primary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(centerX, 18), 11, skinPaint);

    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, 56),
        width: 28,
        height: 52,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(torso, bodyPaint);

    canvas.drawLine(
      Offset(centerX - 13, 47),
      Offset(centerX - 27 + (legSwing * 10), 76),
      linePaint,
    );
    canvas.drawLine(
      Offset(centerX + 13, 47),
      Offset(centerX + 27 - (legSwing * 10), 76),
      linePaint,
    );

    final bend = kneeBend.clamp(0.0, 1.0);

    final leftHip = Offset(centerX - 8, 82);
    final leftKnee = Offset(
      centerX - 12 - (bend * 11) + (legSwing * 12),
      111,
    );
    final leftFoot = Offset(
      centerX - 18 + (bend * 8) + (legSwing * 17),
      138,
    );

    canvas.drawLine(leftHip, leftKnee, linePaint);
    canvas.drawLine(leftKnee, leftFoot, linePaint);

    final rightHip = Offset(centerX + 8, 82);
    final rightKnee = Offset(
      centerX + 12 + (bend * 11) - (legSwing * 12),
      111,
    );
    final rightFoot = Offset(
      centerX + 18 - (bend * 8) - (legSwing * 17),
      138,
    );

    canvas.drawLine(rightHip, rightKnee, linePaint);
    canvas.drawLine(rightKnee, rightFoot, linePaint);

    // IMU Sensor Visual Overlay Dots
    final thighSensorPos = Offset(
      (leftHip.dx + leftKnee.dx) / 2,
      (leftHip.dy + leftKnee.dy) / 2,
    );
    final shinSensorPos = Offset(
      (leftKnee.dx + leftFoot.dx) / 2,
      (leftKnee.dy + leftFoot.dy) / 2,
    );

    final thighGlowPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    final shinGlowPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(thighSensorPos, 6, thighGlowPaint);
    canvas.drawCircle(thighSensorPos, 6, borderPaint);

    canvas.drawCircle(shinSensorPos, 6, shinGlowPaint);
    canvas.drawCircle(shinSensorPos, 6, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PersonGaitPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.kneeBend != kneeBend ||
        oldDelegate.legSwing != legSwing;
  }
}

class _CameraVisionAnimation extends StatelessWidget {
  final double progress;

  const _CameraVisionAnimation({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scanOffset = math.sin(progress * math.pi * 2);


    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: const Color(0xFF38BDF8),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 5),
                  Text(
                    'AI KINEMATICS (10S)',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE SKELETON',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  size: 56,
                  color: Color.lerp(const Color(0xFF38BDF8), const Color(0xFF34D399), (scanOffset + 1) / 2),
                ),
                const SizedBox(height: 4),
                Text(
                  'Align posture in camera frame',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}