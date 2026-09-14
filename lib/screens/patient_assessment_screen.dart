import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/patient_assessment.dart';

class PatientAssessmentScreen extends StatefulWidget {
  final PatientAssessment initialAssessment;

  const PatientAssessmentScreen({
    super.key,
    required this.initialAssessment,
  });

  @override
  State<PatientAssessmentScreen> createState() =>
      _PatientAssessmentScreenState();
}

class _PatientAssessmentScreenState
    extends State<PatientAssessmentScreen> {
  late PatientAssessment _assessment;

  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  String? _validationError;

  @override
  void initState() {
    super.initState();

    _assessment = widget.initialAssessment;

    _ageController = TextEditingController(
      text: _assessment.age?.toString() ?? '',
    );

    _heightController = TextEditingController(
      text: _assessment.heightCm?.toString() ?? '',
    );

    _weightController = TextEditingController(
      text: _assessment.weightKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _updateAssessment({
    int? painScore,
    int? stiffnessScore,
    int? functionalDifficultyScore,
    bool? activityRelatedPain,
    bool? morningStiffness,
    String? sex,
    int? age,
    double? heightCm,
    double? weightKg,
  }) {
    setState(() {
      _assessment = _assessment.copyWith(
        painScore: painScore,
        stiffnessScore: stiffnessScore,
        functionalDifficultyScore: functionalDifficultyScore,
        activityRelatedPain: activityRelatedPain,
        morningStiffness: morningStiffness,
        sex: sex,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
      );

      if (_validationError != null) {
        _validationError = null;
      }
    });
  }

  void _saveAge(String value) {
    _updateAssessment(
      age: int.tryParse(value.trim()),
    );
  }

  void _saveHeight(String value) {
    _updateAssessment(
      heightCm: double.tryParse(value.trim()),
    );
  }

  void _saveWeight(String value) {
    _updateAssessment(
      weightKg: double.tryParse(value.trim()),
    );
  }

  void _continue() {
    FocusScope.of(context).unfocus();

    final validationMessage = _assessment.validationMessage;

    if (validationMessage != null) {
      setState(() {
        _validationError = validationMessage;
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    Navigator.of(context).pop(_assessment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l.get('patientAssessment'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.get('patientAssessmentTitle'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      l.get('patientAssessmentSubtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle(
                      context,
                      l.get('age'),
                    ),

                    const SizedBox(height: 10),

                    _buildBasicInformationCard(context),

                    const SizedBox(height: 24),

                    _sectionTitle(
                      context,
                      l.get('functionalDifficulty'),
                    ),

                    const SizedBox(height: 10),

                    _buildSymptomsCard(context),

                    const SizedBox(height: 24),

                    _buildPrivacyCard(context),

                    const SizedBox(height: 18),

                    if (_validationError != null)
                      _buildValidationError(context),

                    if (_validationError != null)
                      const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _continue,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          l.get('continue'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationError(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 21,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _validationError!,
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildBasicInformationCard(BuildContext context) {
    final l = AppLocalizations.of(context);

    return _card(
      context,
      child: Column(
        children: [
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.get('age'),
              hintText: l.get('enterAge'),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: _saveAge,
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: _assessment.sex,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.get('sex'),
              prefixIcon: const Icon(
                Icons.wc_rounded,
              ),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 'Female',
                child: Text(l.get('female')),
              ),
              DropdownMenuItem(
                value: 'Male',
                child: Text(l.get('male')),
              ),
              DropdownMenuItem(
                value: 'Prefer not to say',
                child: Text(l.get('preferNotToSay')),
              ),
            ],
            onChanged: (value) {
              _updateAssessment(
                sex: value,
              );
            },
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.get('height'),
                    hintText: 'cm',
                    suffixText: 'cm',
                    prefixIcon: const Icon(
                      Icons.height_rounded,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _saveHeight,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.get('weight'),
                    hintText: 'kg',
                    suffixText: 'kg',
                    prefixIcon: const Icon(
                      Icons.monitor_weight_outlined,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _saveWeight,
                ),
              ),
            ],
          ),

          if (_assessment.bmi != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l.get('bmi')}: ${_assessment.bmi!.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomsCard(BuildContext context) {
    final l = AppLocalizations.of(context);

    return _card(
      context,
      child: Column(
        children: [
          _scoreSlider(
            context,
            title: l.get('pain'),
            description: l.get('ratePain'),
            value: _assessment.painScore,
            onChanged: (value) {
              _updateAssessment(
                painScore: value.round(),
              );
            },
          ),

          const Divider(height: 28),

          _scoreSlider(
            context,
            title: l.get('stiffness'),
            description: l.get('rateStiffness'),
            value: _assessment.stiffnessScore,
            onChanged: (value) {
              _updateAssessment(
                stiffnessScore: value.round(),
              );
            },
          ),

          const Divider(height: 28),

          _scoreSlider(
            context,
            title: l.get('functionalDifficulty'),
            description: l.get('rateDifficulty'),
            value: _assessment.functionalDifficultyScore,
            onChanged: (value) {
              _updateAssessment(
                functionalDifficultyScore: value.round(),
              );
            },
          ),

          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.get('activityRelatedPain'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l.get('activityRelatedPain'),
            ),
            value: _assessment.activityRelatedPain,
            onChanged: (value) {
              _updateAssessment(
                activityRelatedPain: value,
              );
            },
          ),

          const SizedBox(height: 4),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.get('morningStiffness'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l.get('morningStiffness'),
            ),
            value: _assessment.morningStiffness,
            onChanged: (value) {
              _updateAssessment(
                morningStiffness: value,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _scoreSlider(
    BuildContext context, {
    required String title,
    required String description,
    required int value,
    required ValueChanged<double> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$value / 10',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: onChanged,
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.get('no'),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            Text(
              l.get('higherOARisk'),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacyCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 21,
            color: colors.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '${l.get('patientAssessmentSubtitle')} '
              '${l.get('notDiagnosis')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),
      child: child,
    );
  }
}