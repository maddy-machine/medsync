enum MovementTestType {
  chairStand,
  fastWalk,
  cameraVision,
}

class MovementTest {
  final MovementTestType type;
  final String name;
  final String description;
  final Duration duration;

  const MovementTest({
    required this.type,
    required this.name,
    required this.description,
    required this.duration,
  });
}

const chairStandTest = MovementTest(
  type: MovementTestType.chairStand,
  name: '30-Second Chair Stand',
  description:
      'Stand up and sit down repeatedly for 30 seconds.',
  duration: Duration(seconds: 30),
);

const fastWalkTest = MovementTest(
  type: MovementTestType.fastWalk,
  name: 'Fast Walk – 20 m',
  description:
      'Walk 20 metres at a fast but safe pace. '
      'Press FINISH TEST immediately after completing the 20 m walk.',
  duration: Duration(seconds: 120),
);

const cameraVisionTest = MovementTest(
  type: MovementTestType.cameraVision,
  name: 'AI Camera Vision Screening',
  description:
      '10-second camera posture, bilateral symmetry, and knee kinematic assessment.',
  duration: Duration(seconds: 10),
);