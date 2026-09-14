class PatientAssessment {
  final int? age;
  final String? sex;

  final double? heightCm;
  final double? weightKg;

  final int painScore;
  final int stiffnessScore;
  final int functionalDifficultyScore;

  final bool activityRelatedPain;
  final bool morningStiffness;

  const PatientAssessment({
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    required this.painScore,
    required this.stiffnessScore,
    required this.functionalDifficultyScore,
    required this.activityRelatedPain,
    required this.morningStiffness,
  });

  factory PatientAssessment.empty() {
    return const PatientAssessment(
      painScore: 0,
      stiffnessScore: 0,
      functionalDifficultyScore: 0,
      activityRelatedPain: false,
      morningStiffness: false,
    );
  }

  double? get bmi {
    final height = heightCm;
    final weight = weightKg;

    if (height == null ||
        weight == null ||
        height <= 0 ||
        weight <= 0) {
      return null;
    }

    final heightMeters = height / 100.0;

    final calculatedBmi =
        weight / (heightMeters * heightMeters);

    if (!calculatedBmi.isFinite) {
      return null;
    }

    return calculatedBmi;
  }

  /// Returns true when the minimum patient information
  /// required for the screening workflow is available.
  ///
  /// Age, height and weight are required because:
  /// - age is part of the deployed hardware feature schema
  /// - height and weight are required to calculate BMI
  /// - BMI is part of the deployed hardware feature schema
  bool get isComplete {
    final validAge =
        age != null && age! > 0 && age! <= 120;

    final validHeight =
        heightCm != null &&
        heightCm! >= 50 &&
        heightCm! <= 250;

    final validWeight =
        weightKg != null &&
        weightKg! >= 20 &&
        weightKg! <= 300;

    final validPain =
        painScore >= 0 && painScore <= 10;

    final validStiffness =
        stiffnessScore >= 0 &&
        stiffnessScore <= 10;

    final validFunctionalDifficulty =
        functionalDifficultyScore >= 0 &&
        functionalDifficultyScore <= 10;

    return validAge &&
        validHeight &&
        validWeight &&
        bmi != null &&
        validPain &&
        validStiffness &&
        validFunctionalDifficulty;
  }

  /// Returns a human-readable reason when the assessment
  /// cannot yet be used for screening.
  String? get validationMessage {
    if (age == null) {
      return 'Enter the patient age.';
    }

    if (age! <= 0 || age! > 120) {
      return 'Enter a valid patient age between 1 and 120 years.';
    }

    if (heightCm == null) {
      return 'Enter the patient height.';
    }

    if (heightCm! < 50 || heightCm! > 250) {
      return 'Enter a valid height between 50 and 250 cm.';
    }

    if (weightKg == null) {
      return 'Enter the patient weight.';
    }

    if (weightKg! < 20 || weightKg! > 300) {
      return 'Enter a valid weight between 20 and 300 kg.';
    }

    if (bmi == null) {
      return 'BMI could not be calculated from the entered height and weight.';
    }

    if (painScore < 0 || painScore > 10) {
      return 'Pain score must be between 0 and 10.';
    }

    if (stiffnessScore < 0 || stiffnessScore > 10) {
      return 'Stiffness score must be between 0 and 10.';
    }

    if (functionalDifficultyScore < 0 ||
        functionalDifficultyScore > 10) {
      return 'Functional difficulty score must be between 0 and 10.';
    }

    return null;
  }

  PatientAssessment copyWith({
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    int? painScore,
    int? stiffnessScore,
    int? functionalDifficultyScore,
    bool? activityRelatedPain,
    bool? morningStiffness,
  }) {
    return PatientAssessment(
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      painScore: painScore ?? this.painScore,
      stiffnessScore:
          stiffnessScore ?? this.stiffnessScore,
      functionalDifficultyScore:
          functionalDifficultyScore ??
              this.functionalDifficultyScore,
      activityRelatedPain:
          activityRelatedPain ??
              this.activityRelatedPain,
      morningStiffness:
          morningStiffness ??
              this.morningStiffness,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'sex': sex,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': bmi,
      'pain_score': painScore,
      'stiffness_score': stiffnessScore,
      'functional_difficulty_score':
          functionalDifficultyScore,
      'activity_related_pain':
          activityRelatedPain,
      'morning_stiffness':
          morningStiffness,
      'is_complete': isComplete,
      'validation_message': validationMessage,
    };
  }

  factory PatientAssessment.fromJson(
    Map<String, dynamic> json,
  ) {
    return PatientAssessment(
      age: (json['age'] as num?)?.toInt(),
      sex: json['sex'] as String?,
      heightCm:
          (json['height_cm'] as num?)?.toDouble(),
      weightKg:
          (json['weight_kg'] as num?)?.toDouble(),
      painScore:
          (json['pain_score'] as num?)?.toInt() ?? 0,
      stiffnessScore:
          (json['stiffness_score'] as num?)?.toInt() ?? 0,
      functionalDifficultyScore:
          (json['functional_difficulty_score'] as num?)
                  ?.toInt() ??
              0,
      activityRelatedPain:
          json['activity_related_pain'] as bool? ??
              false,
      morningStiffness:
          json['morning_stiffness'] as bool? ??
              false,
    );
  }
}