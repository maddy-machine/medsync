import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/movement_test.dart';
import 'test_instruction_animation.dart';

class TestTutorialDialog extends StatelessWidget {
  final MovementTestType testType;
  final VoidCallback? onStartTest;

  const TestTutorialDialog({
    super.key,
    required this.testType,
    this.onStartTest,
  });

  static Future<void> show(
    BuildContext context, {
    required MovementTestType testType,
    VoidCallback? onStartTest,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TestTutorialDialog(
        testType: testType,
        onStartTest: onStartTest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final isCameraVision = testType == MovementTestType.cameraVision;
    final isChairStand = testType == MovementTestType.chairStand;

    final title = isCameraVision
        ? 'AI Camera Vision Screening'
        : isChairStand
            ? l10n.get('chairStand')
            : l10n.get('fastWalk20m');

    final description = isCameraVision
        ? 'Position yourself in front of the camera. The AI will analyze your posture, gait symmetry, and knee kinematics.'
        : isChairStand
            ? l10n.get('chairStandTutorialDesc')
            : l10n.get('fastWalkTutorialDesc');

    final step1 = isCameraVision
        ? 'Stand 2–3 meters back so full body is visible'
        : isChairStand
            ? l10n.get('chairStandStep1')
            : l10n.get('fastWalkStep1');

    final step2 = isCameraVision
        ? 'Perform gentle movement (knee bend or walking in place)'
        : isChairStand
            ? l10n.get('chairStandStep2')
            : l10n.get('fastWalkStep2');

    final step3 = isCameraVision
        ? 'Hold position for 10 seconds while AI processes video'
        : isChairStand
            ? l10n.get('chairStandStep3')
            : l10n.get('fastWalkStep3');


    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: colors.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Header with Icon and Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isChairStand
                      ? Icons.event_seat_rounded
                      : Icons.directions_walk_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('tutorialTitle'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Animation Preview Container
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: TestInstructionAnimation(
                type: testType,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Short summary box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Step by step list
          Text(
            l10n.get('howToPerform'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          _buildStepRow(context, step1),
          const SizedBox(height: 6),
          _buildStepRow(context, step2),
          const SizedBox(height: 6),
          _buildStepRow(context, step3),

          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onStartTest != null) {
                  onStartTest!();
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.get('gotItStartTest'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 10),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: colors.primary,
            size: 18,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}
