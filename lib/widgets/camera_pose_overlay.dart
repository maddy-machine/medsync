import 'dart:math';
import 'package:flutter/material.dart';

/// Overlay mode representing the current phase of vision capture.
enum PoseOverlayMode {
  aligning,
  recording,
  processing,
}

/// A high-tech medical AR pose skeleton overlay that renders real-time
/// skeletal keypoints, bone vectors, joint angles, and alignment guides.
class CameraPoseOverlay extends StatefulWidget {
  final PoseOverlayMode mode;
  final double? liveFlexionAngle;

  const CameraPoseOverlay({
    super.key,
    this.mode = PoseOverlayMode.aligning,
    this.liveFlexionAngle,
  });

  @override
  State<CameraPoseOverlay> createState() => _CameraPoseOverlayState();
}

class _CameraPoseOverlayState extends State<CameraPoseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _PosePainter(
            animationValue: _animController.value,
            mode: widget.mode,
            flexionAngle: widget.liveFlexionAngle ?? 108.0,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PosePainter extends CustomPainter {
  final double animationValue;
  final PoseOverlayMode mode;
  final double flexionAngle;

  _PosePainter({
    required this.animationValue,
    required this.mode,
    required this.flexionAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final primaryColor = mode == PoseOverlayMode.recording
        ? const Color(0xFF10B981) // Emerald Green
        : mode == PoseOverlayMode.processing
            ? const Color(0xFF8B5CF6) // Purple
            : const Color(0xFF06B6D4); // Cyan

    final accentColor = mode == PoseOverlayMode.recording
        ? const Color(0xFF34D399)
        : const Color(0xFF38BDF8);

    // 1. Draw viewfinder bounding guides
    _drawTargetGuide(canvas, size, primaryColor);

    // 2. Draw vertical scanning laser beam
    _drawScanLaser(canvas, size, primaryColor);

    // 3. Draw simulated skeletal keypoints & connections
    _drawSkeleton(canvas, size, primaryColor, accentColor);

    // 4. Draw HUD telemetry
    _drawHudTelemetry(canvas, size, primaryColor);
  }

  void _drawTargetGuide(Canvas canvas, Size size, Color color) {
    final guideRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.52),
      width: size.width * 0.76,
      height: size.height * 0.78,
    );

    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer bounding rounded box
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(24)),
      guidePaint,
    );

    // Corner targeting brackets
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-left
    canvas.drawLine(
      guideRect.topLeft,
      guideRect.topLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.topLeft,
      guideRect.topLeft + const Offset(0, cornerLen),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      guideRect.topRight,
      guideRect.topRight + const Offset(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.topRight,
      guideRect.topRight + const Offset(0, cornerLen),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      guideRect.bottomLeft,
      guideRect.bottomLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.bottomLeft,
      guideRect.bottomLeft + const Offset(0, -cornerLen),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      guideRect.bottomRight,
      guideRect.bottomRight + const Offset(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.bottomRight,
      guideRect.bottomRight + const Offset(0, -cornerLen),
      cornerPaint,
    );
  }

  void _drawScanLaser(Canvas canvas, Size size, Color color) {
    final startY = size.height * 0.16;
    final endY = size.height * 0.88;
    final currentY = startY + (endY - startY) * animationValue;

    final laserGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.18),
        color.withValues(alpha: 0.0),
      ],
    );

    final sweepRect = Rect.fromLTWH(
      size.width * 0.12,
      currentY - 18,
      size.width * 0.76,
      36,
    );

    final laserPaint = Paint()
      ..shader = laserGradient.createShader(sweepRect);

    canvas.drawRect(sweepRect, laserPaint);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(size.width * 0.14, currentY),
      Offset(size.width * 0.86, currentY),
      linePaint,
    );
  }

  void _drawSkeleton(Canvas canvas, Size size, Color color, Color accent) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;

    // Dynamic subtle breathing / motion oscillation
    final sway = sin(animationValue * 2 * pi) * 4.0;
    final kneeBend = sin(animationValue * 2 * pi) * 6.0;

    // Keypoint coordinates relative to center
    final head = Offset(cx + sway * 0.3, cy - size.height * 0.28);
    final neck = Offset(cx + sway * 0.3, cy - size.height * 0.21);

    final leftShoulder = Offset(cx - size.width * 0.15 + sway * 0.4, cy - size.height * 0.19);
    final rightShoulder = Offset(cx + size.width * 0.15 + sway * 0.4, cy - size.height * 0.19);

    final leftElbow = Offset(cx - size.width * 0.22, cy - size.height * 0.08);
    final rightElbow = Offset(cx + size.width * 0.22, cy - size.height * 0.08);

    final leftWrist = Offset(cx - size.width * 0.24, cy + size.height * 0.02);
    final rightWrist = Offset(cx + size.width * 0.24, cy + size.height * 0.02);

    final midHip = Offset(cx + sway * 0.5, cy + size.height * 0.02);
    final leftHip = Offset(cx - size.width * 0.10 + sway * 0.5, cy + size.height * 0.02);
    final rightHip = Offset(cx + size.width * 0.10 + sway * 0.5, cy + size.height * 0.02);

    final leftKnee = Offset(cx - size.width * 0.11, cy + size.height * 0.18 + kneeBend);
    final rightKnee = Offset(cx + size.width * 0.11, cy + size.height * 0.18 - kneeBend);

    final leftAnkle = Offset(cx - size.width * 0.12, cy + size.height * 0.33);
    final rightAnkle = Offset(cx + size.width * 0.12, cy + size.height * 0.33);

    // Draw Bone Lines
    final bonePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    void drawBone(Offset a, Offset b) => canvas.drawLine(a, b, bonePaint);

    drawBone(head, neck);
    drawBone(neck, leftShoulder);
    drawBone(neck, rightShoulder);
    drawBone(leftShoulder, leftElbow);
    drawBone(leftElbow, leftWrist);
    drawBone(rightShoulder, rightElbow);
    drawBone(rightElbow, rightWrist);
    drawBone(neck, midHip);
    drawBone(midHip, leftHip);
    drawBone(midHip, rightHip);
    drawBone(leftHip, leftKnee);
    drawBone(leftKnee, leftAnkle);
    drawBone(rightHip, rightKnee);
    drawBone(rightKnee, rightAnkle);

    // Draw Keypoint Nodes
    final jointPoints = [
      head,
      neck,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftWrist,
      rightWrist,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ];

    final jointFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final jointRing = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in jointPoints) {
      canvas.drawCircle(pt, 4.5, jointFill);
      canvas.drawCircle(pt, 6.5, jointRing);
    }

    // Highlight Knee Tracking with angle arc
    final highlightPaint = Paint()
      ..color = accent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rightKnee, 14.0, highlightPaint);
    canvas.drawCircle(leftKnee, 14.0, highlightPaint);
  }

  void _drawHudTelemetry(Canvas canvas, Size size, Color color) {
    // Top HUD Tag
    final hudText = mode == PoseOverlayMode.recording
        ? 'REC • KINEMATIC TRACKING ACTIVE'
        : mode == PoseOverlayMode.processing
            ? 'ANALYZING POSE SKELETON...'
            : 'AI POSE ALIGNMENT ENGINE';

    final textSpan = TextSpan(
      text: hudText,
      style: TextStyle(
        color: color,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final hudBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (size.width - textPainter.width - 24) * 0.5,
        size.height * 0.06,
        textPainter.width + 24,
        26,
      ),
      const Radius.circular(13),
    );

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(hudBgRect, bgPaint);
    canvas.drawRRect(hudBgRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) * 0.5,
        size.height * 0.06 + 5.5,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.mode != mode ||
        oldDelegate.flexionAngle != flexionAngle;
  }
}
