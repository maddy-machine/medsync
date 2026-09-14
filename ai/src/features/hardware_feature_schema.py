"""
Canonical feature schema for the actual prototype hardware.

The deployed prototype uses two IMUs:

    1. Thigh IMU
    2. Shin IMU

This schema defines movement features that can be derived
from those sensors and passed to the OA screening model.

Important:
These feature definitions describe the engineering prototype.
They are not clinical diagnostic criteria.
"""


# ---------------------------------------------------------
# KNEE KINEMATICS
# ---------------------------------------------------------

KNEE_KINEMATIC_FEATURES = [
    "knee_rom",
    "knee_mean_angle",
    "knee_angle_std",
    "knee_min_angle",
    "knee_max_angle",
]


# ---------------------------------------------------------
# KNEE ANGULAR MOTION
# ---------------------------------------------------------

KNEE_ANGULAR_MOTION_FEATURES = [
    "knee_angular_velocity_mean",
    "knee_angular_velocity_std",
    "knee_angular_acceleration_mean",
    "knee_angular_acceleration_std",
]


# ---------------------------------------------------------
# THIGH IMU FEATURES
# ---------------------------------------------------------

THIGH_IMU_FEATURES = [
    "thigh_acceleration_mean",
    "thigh_acceleration_std",
    "thigh_gyro_mean",
    "thigh_gyro_std",
]


# ---------------------------------------------------------
# SHIN IMU FEATURES
# ---------------------------------------------------------

SHIN_IMU_FEATURES = [
    "shin_acceleration_mean",
    "shin_acceleration_std",
    "shin_gyro_mean",
    "shin_gyro_std",
]


# ---------------------------------------------------------
# INTER-SEGMENT / MOVEMENT QUALITY
# ---------------------------------------------------------

MOVEMENT_QUALITY_FEATURES = [
    "knee_angle_cycle_variability",
    "knee_velocity_cycle_variability",
    "movement_smoothness",
    "movement_variability",
]


# ---------------------------------------------------------
# TEMPORAL FEATURES
# ---------------------------------------------------------

TEMPORAL_FEATURES = [
    "movement_cycle_duration_mean",
    "movement_cycle_duration_std",
    "movement_cycle_duration_cv",
]


# ---------------------------------------------------------
# FUNCTIONAL TEST FEATURES
# ---------------------------------------------------------

FUNCTIONAL_TEST_FEATURES = [
    "chair_stand_repetitions",
    "chair_stand_average_cycle_duration",
    "walk_duration_seconds",
    "walk_cycle_duration_mean",
    "walk_cycle_duration_std",
]


# ---------------------------------------------------------
# PATIENT CONTEXT
# ---------------------------------------------------------

PATIENT_CONTEXT_FEATURES = [
    "patient_age",
    "patient_bmi",
]


# ---------------------------------------------------------
# COMPLETE CANONICAL SCHEMA
# ---------------------------------------------------------

CANONICAL_FEATURE_SCHEMA = (
    KNEE_KINEMATIC_FEATURES
    + KNEE_ANGULAR_MOTION_FEATURES
    + THIGH_IMU_FEATURES
    + SHIN_IMU_FEATURES
    + MOVEMENT_QUALITY_FEATURES
    + TEMPORAL_FEATURES
    + FUNCTIONAL_TEST_FEATURES
    + PATIENT_CONTEXT_FEATURES
)


def get_feature_names() -> list[str]:
    """
    Return the complete ordered feature schema.
    """
    return list(
        CANONICAL_FEATURE_SCHEMA
    )


def get_feature_count() -> int:
    """
    Return the number of canonical features.
    """
    return len(
        CANONICAL_FEATURE_SCHEMA
    )


def validate_feature_vector(
    features: dict[str, float],
) -> tuple[bool, list[str]]:
    """
    Validate that a feature dictionary contains
    the canonical features.

    Returns:
        (is_valid, missing_features)
    """

    missing_features = [
        feature
        for feature in CANONICAL_FEATURE_SCHEMA
        if feature not in features
    ]

    return (
        len(missing_features) == 0,
        missing_features,
    )


def print_schema() -> None:
    """
    Print the canonical hardware feature schema.
    """

    print(
        "Canonical Hardware Feature Schema"
    )

    print("=" * 60)

    for index, feature in enumerate(
        CANONICAL_FEATURE_SCHEMA,
        start=1,
    ):
        print(
            f"{index:2d}. {feature}"
        )

    print()

    print(
        f"Total features: "
        f"{len(CANONICAL_FEATURE_SCHEMA)}"
    )


if __name__ == "__main__":
    print_schema()