import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportMetric {
  final String label;
  final String value;

  const ReportMetric({
    required this.label,
    required this.value,
  });
}

class ReportQualityData {
  final double score;
  final String label;
  final int sampleCount;
  final double durationSeconds;
  final double samplingRate;
  final double sampleCoverage;
  final double timestampRegularity;
  final double signalQuality;
  final double movementPresence;

  const ReportQualityData({
    required this.score,
    required this.label,
    required this.sampleCount,
    required this.durationSeconds,
    required this.samplingRate,
    required this.sampleCoverage,
    required this.timestampRegularity,
    required this.signalQuality,
    required this.movementPresence,
  });
}

class ScreeningReportData {
  final DateTime generatedAt;
  final String? patientId;

  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;

  final int painScore;
  final int stiffnessScore;
  final int functionalDifficultyScore;
  final bool activityRelatedPain;
  final bool morningStiffness;

  final List<ReportMetric> chairStandMetrics;
  final List<ReportMetric> fastWalkMetrics;
  final List<ReportMetric> kneeMetrics;

  final ReportQualityData? chairStandQuality;
  final ReportQualityData? fastWalkQuality;

  final bool screeningAvailable;
  final String? riskLabel;
  final double? riskProbability;
  final String? modelVersion;
  final double? threshold;
  final List<String> topFactors;
  final String? recommendation;

  final String modelType;
  final String modelSchema;
  final int modelFeatureCount;

  const ScreeningReportData({
    required this.generatedAt,
    required this.patientId,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
    required this.painScore,
    required this.stiffnessScore,
    required this.functionalDifficultyScore,
    required this.activityRelatedPain,
    required this.morningStiffness,
    required this.chairStandMetrics,
    required this.fastWalkMetrics,
    required this.kneeMetrics,
    required this.chairStandQuality,
    required this.fastWalkQuality,
    required this.screeningAvailable,
    required this.riskLabel,
    required this.riskProbability,
    required this.modelVersion,
    required this.threshold,
    required this.topFactors,
    required this.recommendation,
    required this.modelType,
    required this.modelSchema,
    required this.modelFeatureCount,
  });
}

class ReportPdfService {
  const ReportPdfService();

  Future<Uint8List> generate(
    ScreeningReportData data,
  ) async {
    final document = pw.Document(
      title: 'MedSync AI-Assisted Screening Report',
      author: 'MedSync',
      subject:
          'AI-assisted preliminary osteoarthritis risk screening',
    );

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          32,
          34,
          32,
          34,
        ),
        theme: theme,
        header: (context) => _buildHeader(),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildTitle(data),
          pw.SizedBox(height: 18),

          _buildPatientSection(data),
          pw.SizedBox(height: 14),

          _buildMovementSection(
            title: '30-Second Chair Stand',
            metrics: data.chairStandMetrics,
          ),
          pw.SizedBox(height: 14),

          _buildMovementSection(
            title: 'Fast Walk - 40 m',
            metrics: data.fastWalkMetrics,
          ),
          pw.SizedBox(height: 14),

          _buildMovementSection(
            title: 'Knee / Relative Motion Features',
            metrics: data.kneeMetrics,
          ),
          pw.SizedBox(height: 14),

          _buildQualitySection(
            title: 'Chair Stand Recording Quality',
            quality: data.chairStandQuality,
          ),
          pw.SizedBox(height: 14),

          _buildQualitySection(
            title: 'Fast Walk Recording Quality',
            quality: data.fastWalkQuality,
          ),
          pw.SizedBox(height: 14),

          _buildScreeningSection(data),
          pw.SizedBox(height: 14),

          _buildTechnicalSection(data),
          pw.SizedBox(height: 14),

          _buildClinicalValidationSection(),
          pw.SizedBox(height: 14),

          _buildDisclaimer(),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.7,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MEDSYNC',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'AI-Assisted Screening',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
    pw.Context context,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Prototype screening report - Not a diagnosis',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTitle(
    ScreeningReportData data,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
            const pw.BorderRadius.all(
          pw.Radius.circular(8),
        ),
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AI-Assisted Preliminary Screening Report',
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Osteoarthritis-associated movement and symptom assessment',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoText(
                  'Generated',
                  _formatDateTime(
                    data.generatedAt,
                  ),
                ),
              ),
              pw.Expanded(
                child: _infoText(
                  'Report ID',
                  data.patientId ?? 'Not provided',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPatientSection(
    ScreeningReportData data,
  ) {
    return _section(
      title: 'Patient Assessment',
      child: pw.Column(
        children: [
          _table([
            [
              'Age',
              _formatInt(data.age, 'Not available'),
              'Sex',
              _value(data.sex),
            ],
            [
              'Height',
              _formatDouble(data.heightCm, ' cm'),
              'Weight',
              _formatDouble(data.weightKg, ' kg'),
            ],
            [
              'BMI',
              _formatDouble(data.bmi),
              'Pain Score',
              '${data.painScore}/10',
            ],
            [
              'Stiffness Score',
              '${data.stiffnessScore}/10',
              'Functional Difficulty',
              '${data.functionalDifficultyScore}/10',
            ],
            [
              'Activity-related Pain',
              data.activityRelatedPain
                  ? 'Yes'
                  : 'No',
              'Morning Stiffness',
              data.morningStiffness
                  ? 'Yes'
                  : 'No',
            ],
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildMovementSection({
    required String title,
    required List<ReportMetric> metrics,
  }) {
    if (metrics.isEmpty) {
      return _section(
        title: title,
        child: _emptyMessage(
          'No result data was available for this test.',
        ),
      );
    }

    return _section(
      title: title,
      child: _metricTable(metrics),
    );
  }

  pw.Widget _buildQualitySection({
    required String title,
    required ReportQualityData? quality,
  }) {
    if (quality == null) {
      return _section(
        title: title,
        child: _emptyMessage(
          'Recording quality data was not available.',
        ),
      );
    }

    return _section(
      title: title,
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _qualityScoreCard(
                  quality.score,
                  quality.label,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _infoBox(
                  'Samples',
                  quality.sampleCount.toString(),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _infoBox(
                  'Sampling Rate',
                  '${quality.samplingRate.toStringAsFixed(1)} Hz',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _table([
            [
              'Recorded Duration',
              '${quality.durationSeconds.toStringAsFixed(2)} s',
              'Sample Coverage',
              '${quality.sampleCoverage.toStringAsFixed(1)}%',
            ],
            [
              'Timestamp Regularity',
              '${quality.timestampRegularity.toStringAsFixed(1)}%',
              'Signal Quality',
              '${quality.signalQuality.toStringAsFixed(1)}%',
            ],
            [
              'Movement Presence',
              '${quality.movementPresence.toStringAsFixed(1)}%',
              'Quality Interpretation',
              quality.label,
            ],
          ]),
          pw.SizedBox(height: 6),
          pw.Text(
            'Recording quality describes sensor-data completeness and movement capture. '
            'It is not an AI confidence score and does not represent clinical validity.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildScreeningSection(
    ScreeningReportData data,
  ) {
    final available =
        data.screeningAvailable &&
        data.riskLabel != null;

    return _section(
      title: 'AI-Assisted Screening Result',
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          if (available) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
                borderRadius:
                    const pw.BorderRadius.all(
                  pw.Radius.circular(6),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'OA-associated risk assessment',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight:
                                pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          data.riskLabel!,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight:
                                pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.riskProbability != null)
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Model probability',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color:
                                PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${(data.riskProbability! * 100).toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight:
                                pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            _table([
              [
                'Model Version',
                _value(data.modelVersion),
                'Threshold',
                _formatProbability(
                  data.threshold,
                ),
              ],
            ]),
            pw.SizedBox(height: 10),
            pw.Text(
              'Top contributing factors',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            if (data.topFactors.isEmpty)
              _emptyMessage(
                'No contributing factors were available.',
              )
            else
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: data.topFactors
                    .map(
                      (factor) => pw.Padding(
                        padding:
                            const pw.EdgeInsets.only(
                          bottom: 4,
                        ),
                        child: pw.Text(
                          '- $factor',
                          style:
                              const pw.TextStyle(
                            fontSize: 9,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ] else ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
                borderRadius:
                    const pw.BorderRadius.all(
                  pw.Radius.circular(6),
                ),
              ),
              child: pw.Text(
                'AI-assisted screening was unavailable for this assessment. '
                'Clinical evaluation is recommended.',
                style: const pw.TextStyle(
                  fontSize: 10,
                ),
              ),
            ),
          ],
          if (data.recommendation != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Recommendation',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              data.recommendation!,
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildTechnicalSection(
    ScreeningReportData data,
  ) {
    return _section(
      title: 'Technical Model Information',
      child: _table([
        [
          'Model Type',
          data.modelType,
          'Feature Count',
          data.modelFeatureCount.toString(),
        ],
        [
          'Schema',
          data.modelSchema,
          'Model Version',
          _value(data.modelVersion),
        ],
      ]),
    );
  }

  pw.Widget _buildClinicalValidationSection() {
    return _section(
      title: 'Clinical Validation Status',
      child: pw.Text(
        'This prototype provides AI-assisted preliminary screening only. '
        'Clinical validation has not been established by this report. '
        'Before clinical deployment, the system requires an adequately powered '
        'clinically labelled dataset, a predefined validation protocol, '
        'independent evaluation, calibration assessment, and subgroup analysis. '
        'Performance should be reported using appropriate clinical metrics such '
        'as sensitivity, specificity, AUROC and calibration.',
        style: const pw.TextStyle(
          fontSize: 9,
          lineSpacing: 2,
        ),
      ),
    );
  }

  pw.Widget _buildDisclaimer() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey400,
        ),
        borderRadius:
            const pw.BorderRadius.all(
          pw.Radius.circular(6),
        ),
      ),
      child: pw.Text(
        'IMPORTANT: This report is an AI-assisted preliminary screening output. '
        'It is not a definitive diagnosis and must not replace assessment by a '
        'qualified healthcare professional. Results should be interpreted together '
        'with symptoms, functional assessment and appropriate clinical evaluation.',
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _section({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
        borderRadius:
            const pw.BorderRadius.all(
          pw.Radius.circular(6),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  pw.Widget _metricTable(
    List<ReportMetric> metrics,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        _tableHeaderRow(
          ['Metric', 'Value'],
        ),
        ...metrics.map(
          (metric) => pw.TableRow(
            children: [
              _tableCell(metric.label),
              _tableCell(metric.value),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _table(
    List<List<String>> rows,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (value) => _tableCell(value),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _tableHeaderRow(
    List<String> values,
  ) {
    return pw.TableRow(
      children: values
          .map(
            (value) => pw.Container(
              padding:
                  const pw.EdgeInsets.all(6),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _tableCell(
    String value,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        style: const pw.TextStyle(
          fontSize: 8.5,
        ),
      ),
    );
  }

  pw.Widget _qualityScoreCard(
    double score,
    String label,
  ) {
    return _infoBox(
      'Recording Quality',
      '${score.toStringAsFixed(0)}/100 - $label',
    );
  }

  pw.Widget _infoBox(
    String title,
    String value,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
            const pw.BorderRadius.all(
          pw.Radius.circular(5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoText(
    String title,
    String value,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _emptyMessage(
    String message,
  ) {
    return pw.Text(
      message,
      style: const pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.grey700,
      ),
    );
  }

  String _value(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not available';
    }

    return value;
  }

  String _formatInt(
    int? value,
    String suffix,
  ) {
    return value == null
        ? suffix
        : value.toString();
  }

  String _formatDouble(
    double? value, [
    String suffix = '',
  ]) {
    if (value == null || !value.isFinite) {
      return 'Not available';
    }

    return '${value.toStringAsFixed(1)}$suffix';
  }

  String _formatProbability(
    double? value,
  ) {
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        value > 1) {
      return 'Not available';
    }

    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _formatDateTime(
    DateTime value,
  ) {
    final local = value.toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${local.day}/${local.month}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}