import 'package:flutter/material.dart';

class ClinicalValidationCard extends StatelessWidget {
  const ClinicalValidationCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.biotech_outlined,
                  color: colors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Validation & Limitations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildStatusRow(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: 'Technical pipeline',
            value: 'Validated in prototype',
            positive: true,
          ),

          const SizedBox(height: 11),

          _buildStatusRow(
            context,
            icon: Icons.pending_outlined,
            title: 'Clinical validation',
            value: 'Pending clinical study',
            positive: false,
          ),

          const SizedBox(height: 16),

          Text(
            'What this means',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'The application currently demonstrates the complete '
            'technical screening pipeline, from patient assessment '
            'and movement capture through feature extraction and '
            'AI-assisted risk estimation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Clinical validation requires real participant data with '
            'appropriate clinical ground truth and independent '
            'evaluation of measures such as sensitivity, specificity, '
            'AUC and calibration. No unsupported clinical performance '
            'metrics are presented here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 13),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 19,
                  color: colors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This system is intended for AI-assisted '
                    'preliminary screening support and does not '
                    'provide a definitive diagnosis or replace '
                    'clinical evaluation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          Text(
            'Planned validation pathway',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          _buildStep(
            context,
            '1',
            'Collect clinically labelled participant data',
          ),
          _buildStep(
            context,
            '2',
            'Capture the same movement tests with the IMU system',
          ),
          _buildStep(
            context,
            '3',
            'Evaluate the model on an independent test set',
          ),
          _buildStep(
            context,
            '4',
            'Measure sensitivity, specificity, AUC and calibration',
          ),
          _buildStep(
            context,
            '5',
            'Conduct prospective clinical evaluation',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool positive,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = positive ? colors.primary : colors.tertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: statusColor,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    String number,
    String text,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}