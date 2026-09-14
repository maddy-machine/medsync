import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/screening_result.dart';
import '../services/movement_test_controller.dart';
import '../services/report_pdf_service.dart';
import '../services/screening_report_builder.dart';
import '../widgets/clinical_validation_card.dart';

class ScreeningResultsScreen extends StatelessWidget {
  final MovementTestController controller;

  const ScreeningResultsScreen({
    super.key,
    required this.controller,
  });

  Future<void> _downloadReport(
    BuildContext context,
  ) async {
    final messenger =
        ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Generating screening report...',
          ),
          duration: Duration(seconds: 2),
        ),
      );

    try {
      final reportData =
          const ScreeningReportBuilder().build(
        controller,
      );

      final pdfBytes =
          await const ReportPdfService().generate(
        reportData,
      );

      final generatedAt =
          reportData.generatedAt.toLocal();

      final fileName =
          'MedSync_Screening_Report_'
          '${generatedAt.year}-'
          '${generatedAt.month.toString().padLeft(2, '0')}-'
          '${generatedAt.day.toString().padLeft(2, '0')}_'
          '${generatedAt.hour.toString().padLeft(2, '0')}-'
          '${generatedAt.minute.toString().padLeft(2, '0')}.pdf';

      final savedLocation =
          await const MethodChannel(
        'com.example.medsync_app/report',
      ).invokeMethod<String>(
        'savePdfToDownloads',
        <String, dynamic>{
          'fileName': fileName,
          'bytes': pdfBytes,
        },
      );

      if (savedLocation == null ||
          savedLocation.isEmpty) {
        throw StateError(
          'Android did not return a saved report location.',
        );
      }

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Report saved to Downloads/MedSync.',
          ),
        ),
      );
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not generate the report: $error',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final screening =
        controller.screeningResult;

    final chairStand =
        controller.chairStandResult;

    final fastWalk =
        controller.fastWalkResult;

    final kneeFeatures =
        controller.fastWalkKneeFeatures ??
            controller.chairStandKneeFeatures;

    final chairQuality =
        controller.chairStandQuality;

    final fastWalkQuality =
        controller.fastWalkQuality;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screening Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildHeader(
                theme,
                colors,
              ),

              const SizedBox(height: 20),

              _buildRiskCard(
                theme,
                colors,
                screening,
              ),

              const SizedBox(height: 18),

              if (screening != null &&
                  screening
                      .contributingFactors
                      .isNotEmpty)
                _buildFactorsCard(
                  theme,
                  colors,
                  screening,
                ),

              if (chairQuality != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 18,
                  ),
                  child:
                      _buildTestQualityCard(
                    theme,
                    colors,
                    title:
                        'Chair Stand Test Quality',
                    icon:
                        Icons.chair_rounded,
                    quality: chairQuality,
                  ),
                ),

              if (fastWalkQuality != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 14,
                  ),
                  child:
                      _buildTestQualityCard(
                    theme,
                    colors,
                    title:
                        'Fast Walk Test Quality',
                    icon: Icons
                        .directions_walk_rounded,
                    quality:
                        fastWalkQuality,
                  ),
                ),

              if (kneeFeatures != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 18,
                  ),
                  child: _buildKneeCard(
                    theme,
                    colors,
                    kneeFeatures,
                  ),
                ),

              if (chairStand != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 18,
                  ),
                  child:
                      _buildChairStandCard(
                    theme,
                    colors,
                    chairStand,
                  ),
                ),

              if (fastWalk != null)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 18,
                  ),
                  child: _buildFastWalkCard(
                    theme,
                    colors,
                    fastWalk,
                  ),
                ),

              const SizedBox(height: 18),

              const ClinicalValidationCard(),

              const SizedBox(height: 18),

              _buildClinicalCard(
                theme,
                colors,
                screening,
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton.icon(
                  onPressed: () =>
                      _downloadReport(context),
                  icon: const Icon(
                    Icons
                        .picture_as_pdf_rounded,
                  ),
                  label: const Text(
                    'DOWNLOAD REPORT',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style:
                      FilledButton.styleFrom(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context)
                        .pop();
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text(
                    'DONE',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'AI-assisted preliminary screening • Not a diagnosis',
                  textAlign: TextAlign.center,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color:
                colors.primaryContainer,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Text(
            'SCREENING COMPLETE',
            style: TextStyle(
              color: colors.primary,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),

        const SizedBox(height: 11),

        Text(
          'Your movement assessment',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'The recorded movement data has been '
          'processed and combined with your '
          'assessment information.',
          style: theme
              .textTheme
              .bodyMedium
              ?.copyWith(
            color:
                colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(
    ThemeData theme,
    ColorScheme colors,
    ScreeningResult? result,
  ) {
    if (result == null ||
        !result.modelAvailable ||
        result.probability == null) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: colors
              .surfaceContainerHighest
              .withValues(alpha: 0.65),
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: colors
                .outlineVariant
                .withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconContainer(
                  colors,
                  Icons
                      .psychology_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI screening unavailable',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              result?.explanation ??
                  'A compatible trained AI model '
                  'is not currently connected to '
                  'this application.',
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                    colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'No artificial risk score has been generated.',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final probability =
        result.probability!;

    final higher =
        result.riskLevel ==
            ScreeningRiskLevel.higher;

    final title =
        result.riskLabel;

    final icon = higher
        ? Icons.warning_amber_rounded
        : Icons.verified_outlined;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: higher
            ? colors.errorContainer
                .withValues(alpha: 0.7)
            : colors.primaryContainer
                .withValues(alpha: 0.55),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: higher
              ? colors.error
                  .withValues(alpha: 0.18)
              : colors.primary
                  .withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconContainer(
                colors,
                icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            '${(probability * 100).toStringAsFixed(1)}%',
            style: theme
                .textTheme
                .displaySmall
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'model-estimated OA-associated risk probability',
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          if (result.threshold != null)
            _buildMetricRow(
              colors,
              'Screening threshold',
              '${(result.threshold! * 100).toStringAsFixed(0)}%',
            ),

          const SizedBox(height: 13),

          Text(
            result.explanation,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard(
    ThemeData theme,
    ColorScheme colors,
    ScreeningResult result,
  ) {
    return _buildSectionCard(
      theme,
      colors,
      title: 'Key contributing factors',
      icon: Icons.insights_rounded,
      child: Column(
        children: result
            .contributingFactors
            .map(
              (factor) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin:
                          const EdgeInsets.only(
                        top: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            colors.primary,
                        shape:
                            BoxShape.circle,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        factor,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height: 1.4,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTestQualityCard(
    ThemeData theme,
    ColorScheme colors, {
    required String title,
    required IconData icon,
    required TestQualityResult
        quality,
  }) {
    final score = quality.score;

    final Color statusColor;
    final Color statusBackground;

    if (score >= 85) {
      statusColor = colors.primary;
      statusBackground =
          colors.primaryContainer;
    } else if (score >= 70) {
      statusColor = colors.primary;
      statusBackground =
          colors.primaryContainer
              .withValues(alpha: 0.65);
    } else if (score >= 50) {
      statusColor = colors.tertiary;
      statusBackground =
          colors.tertiaryContainer;
    } else {
      statusColor = colors.error;
      statusBackground =
          colors.errorContainer;
    }

    return _buildSectionCard(
      theme,
      colors,
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Data quality score',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${score.toStringAsFixed(0)}/100',
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      statusBackground,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  quality.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(8),
            child:
                LinearProgressIndicator(
              value:
                  (score / 100).clamp(
                0.0,
                1.0,
              ),
              minHeight: 8,
              backgroundColor: colors
                  .surfaceContainerHighest,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            quality.summary,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 15),

          _buildMetricRow(
            colors,
            'Recorded samples',
            '${quality.sampleCount}',
          ),

          const SizedBox(height: 9),

          _buildMetricRow(
            colors,
            'Recording duration',
            '${quality.durationSeconds.toStringAsFixed(1)} s',
          ),

          const SizedBox(height: 9),

          _buildMetricRow(
            colors,
            'Sampling rate',
            '${quality.samplingRate.toStringAsFixed(1)} Hz',
          ),

          const SizedBox(height: 14),

          _buildQualityBreakdown(
            theme,
            colors,
            'Sample coverage',
            quality.sampleCoverage,
          ),

          const SizedBox(height: 8),

          _buildQualityBreakdown(
            theme,
            colors,
            'Timestamp regularity',
            quality.timestampRegularity,
          ),

          const SizedBox(height: 8),

          _buildQualityBreakdown(
            theme,
            colors,
            'Sensor signal quality',
            quality.signalQuality,
          ),

          const SizedBox(height: 8),

          _buildQualityBreakdown(
            theme,
            colors,
            'Movement presence',
            quality.movementPresence,
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color:
                    colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This score describes the technical '
                  'quality of the recorded sensor data. '
                  'It is not an AI confidence score and '
                  'does not represent a clinical diagnosis.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBreakdown(
    ThemeData theme,
    ColorScheme colors,
    String label,
    double value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildKneeCard(
    ThemeData theme,
    ColorScheme colors,
    dynamic features,
  ) {
    return _buildSectionCard(
      theme,
      colors,
      title: 'Knee movement',
      icon:
          Icons.accessibility_new_rounded,
      child: Column(
        children: [
          _buildMetricRow(
            colors,
            'Range of motion',
            '${features.rangeOfMotion.toStringAsFixed(1)}°',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Minimum angle',
            '${features.minimumAngle.toStringAsFixed(1)}°',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Maximum angle',
            '${features.maximumAngle.toStringAsFixed(1)}°',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Movement variability',
            '${features.angleCycleVariability.toStringAsFixed(2)}°',
          ),
        ],
      ),
    );
  }

  Widget _buildChairStandCard(
    ThemeData theme,
    ColorScheme colors,
    dynamic result,
  ) {
    return _buildSectionCard(
      theme,
      colors,
      title: 'Chair Stand',
      icon: Icons.chair_rounded,
      child: Column(
        children: [
          _buildMetricRow(
            colors,
            'Repetitions',
            '${result.repetitions}',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Average cycle',
            '${result.averageCycleDuration.toStringAsFixed(2)} s',
          ),
        ],
      ),
    );
  }

  Widget _buildFastWalkCard(
    ThemeData theme,
    ColorScheme colors,
    dynamic result,
  ) {
    return _buildSectionCard(
      theme,
      colors,
      title: 'Fast Walk',
      icon:
          Icons.directions_walk_rounded,
      child: Column(
        children: [
          _buildMetricRow(
            colors,
            'Walk duration',
            '${result.durationSeconds.toStringAsFixed(2)} s',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Movement variability',
            '${result.movementVariability.toStringAsFixed(3)}',
          ),

          const SizedBox(height: 11),

          _buildMetricRow(
            colors,
            'Shin dynamic acceleration',
            '${result.shinDynamicAccelerationMean.toStringAsFixed(3)}',
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalCard(
    ThemeData theme,
    ColorScheme colors,
    ScreeningResult? result,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors
            .secondaryContainer
            .withValues(alpha: 0.45),
        borderRadius:
            BorderRadius.circular(19),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: colors.primary,
            size: 24,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical interpretation',
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  result?.recommendation ??
                      'Clinical evaluation is recommended '
                      'for interpretation and follow-up.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme,
    ColorScheme colors, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors
              .outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallIcon(
                colors,
                icon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    ColorScheme colors,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildIconContainer(
    ColorScheme colors,
    IconData icon,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color: colors.primary,
        size: 26,
      ),
    );
  }

  Widget _buildSmallIcon(
    ColorScheme colors,
    IconData icon,
  ) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: colors.primary,
        size: 20,
      ),
    );
  }
}