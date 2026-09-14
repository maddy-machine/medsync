import '../models/patient_assessment.dart';

class PatientAssessmentFeatures {
  final Map<String, double> values;

  const PatientAssessmentFeatures({
    required this.values,
  });

  factory PatientAssessmentFeatures.fromAssessment(
    PatientAssessment assessment,
  ) {
    final values = <String, double>{
      'patient_pain_score':
          assessment.painScore.toDouble(),

      'patient_stiffness_score':
          assessment.stiffnessScore.toDouble(),

      'patient_functional_difficulty':
          assessment.functionalDifficultyScore
              .toDouble(),

      'patient_activity_related_pain':
          assessment.activityRelatedPain
              ? 1.0
              : 0.0,

      'patient_morning_stiffness':
          assessment.morningStiffness
              ? 1.0
              : 0.0,
    };

    if (assessment.age != null) {
      values['patient_age'] =
          assessment.age!.toDouble();
    }

    if (assessment.sex != null) {
      values['patient_sex_male'] =
          assessment.sex == 'Male'
              ? 1.0
              : 0.0;

      values['patient_sex_female'] =
          assessment.sex == 'Female'
              ? 1.0
              : 0.0;
    }

    return PatientAssessmentFeatures(
      values: values,
    );
  }

  List<String> get names =>
      values.keys.toList();

  int get length =>
      values.length;

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(
      values,
    );
  }
}