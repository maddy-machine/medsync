from pathlib import Path
import json
import random

import numpy as np
import pandas as pd


# ============================================================
# PATHS
# ============================================================

AI_ROOT = Path(__file__).resolve().parents[2]

DATA_ROOT = (
    AI_ROOT
    / "data"
    / "processed"
)

TRAIN_FILE = (
    DATA_ROOT
    / "hardware_31_train.csv"
)

TEST_FILE = (
    DATA_ROOT
    / "hardware_31_test.csv"
)

MODEL_OUTPUT_FILE = (
    DATA_ROOT
    / "oa_hardware_31_v1_model.json"
)

METRICS_OUTPUT_FILE = (
    DATA_ROOT
    / "hardware_31_model_metrics.json"
)


# ============================================================
# MODEL CONFIGURATION
# ============================================================

MODEL_TYPE = "logistic_regression"

MODEL_VERSION = "hardware_31_v1"

FEATURE_SCHEMA = "hardware_31_v1"

TARGET_COLUMN = "oa_label"

GROUP_COLUMN = "subject_id"

IDENTIFIER_COLUMNS = [
    "subject_id",
    "trial_id",
]


RANDOM_STATE = 42

VALIDATION_SIZE = 0.20

LEARNING_RATE = 0.01

EPOCHS = 3000

L2_STRENGTH = 0.01

TARGET_SENSITIVITY = 0.80

THRESHOLD_STEP = 0.05


# ============================================================
# CANONICAL 31-FEATURE SCHEMA
# ============================================================

FEATURE_COLUMNS = [
    "knee_rom",
    "knee_mean_angle",
    "knee_angle_std",
    "knee_min_angle",
    "knee_max_angle",
    "knee_angular_velocity_mean",
    "knee_angular_velocity_std",
    "knee_angular_acceleration_mean",
    "knee_angular_acceleration_std",
    "thigh_acceleration_mean",
    "thigh_acceleration_std",
    "thigh_gyro_mean",
    "thigh_gyro_std",
    "shin_acceleration_mean",
    "shin_acceleration_std",
    "shin_gyro_mean",
    "shin_gyro_std",
    "knee_angle_cycle_variability",
    "knee_velocity_cycle_variability",
    "movement_smoothness",
    "movement_variability",
    "movement_cycle_duration_mean",
    "movement_cycle_duration_std",
    "movement_cycle_duration_cv",
    "chair_stand_repetitions",
    "chair_stand_average_cycle_duration",
    "walk_duration_seconds",
    "walk_cycle_duration_mean",
    "walk_cycle_duration_std",
    "patient_age",
    "patient_bmi",
]


# ============================================================
# NUMERICAL HELPERS
# ============================================================

def sigmoid(
    values: np.ndarray,
) -> np.ndarray:
    clipped = np.clip(
        values,
        -500,
        500,
    )

    return 1.0 / (
        1.0 + np.exp(-clipped)
    )


def standardize_train_other(
    x_train: np.ndarray,
    x_other: np.ndarray,
) -> tuple[
    np.ndarray,
    np.ndarray,
    np.ndarray,
    np.ndarray,
]:
    means = np.mean(
        x_train,
        axis=0,
    )

    standard_deviations = np.std(
        x_train,
        axis=0,
    )

    standard_deviations[
        standard_deviations < 1e-12
    ] = 1.0

    standardized_train = (
        x_train - means
    ) / standard_deviations

    standardized_other = (
        x_other - means
    ) / standard_deviations

    return (
        standardized_train,
        standardized_other,
        means,
        standard_deviations,
    )


# ============================================================
# DATA VALIDATION
# ============================================================

def validate_dataframe(
    dataframe: pd.DataFrame,
    filename: str,
) -> None:

    required_columns = (
        IDENTIFIER_COLUMNS
        + [TARGET_COLUMN]
        + FEATURE_COLUMNS
    )

    missing_columns = [
        column
        for column in required_columns
        if column not in dataframe.columns
    ]

    if missing_columns:
        raise ValueError(
            f"{filename} is missing required "
            f"columns:\n"
            + "\n".join(
                f"  - {column}"
                for column in missing_columns
            )
        )

    if len(FEATURE_COLUMNS) != 31:
        raise RuntimeError(
            "Internal feature schema must "
            "contain exactly 31 features."
        )

    labels = set(
        dataframe[TARGET_COLUMN]
        .dropna()
        .astype(int)
        .unique()
        .tolist()
    )

    if not labels.issubset({0, 1}):
        raise ValueError(
            f"{filename} contains labels other "
            f"than 0 and 1: {labels}"
        )

    if len(labels) < 2:
        raise ValueError(
            f"{filename} must contain both "
            "OA classes: 0 and 1."
        )

    for feature in FEATURE_COLUMNS:
        values = pd.to_numeric(
            dataframe[feature],
            errors="coerce",
        )

        if values.isna().any():
            raise ValueError(
                f"{filename} contains missing or "
                f"non-numeric values in feature "
                f"'{feature}'."
            )

        if not np.isfinite(
            values.to_numpy(
                dtype=float,
            )
        ).all():
            raise ValueError(
                f"{filename} contains non-finite "
                f"values in feature "
                f"'{feature}'."
            )


def validate_subject_labels(
    dataframe: pd.DataFrame,
) -> None:

    subject_label_counts = (
        dataframe.groupby(
            GROUP_COLUMN
        )[TARGET_COLUMN]
        .nunique()
    )

    inconsistent_subjects = (
        subject_label_counts[
            subject_label_counts > 1
        ]
    )

    if not inconsistent_subjects.empty:
        raise ValueError(
            "A subject has multiple OA labels. "
            "Subject-level labels must be "
            "consistent.\n"
            f"Subjects:\n"
            f"{inconsistent_subjects.index.tolist()}"
        )


# ============================================================
# SUBJECT-LEVEL VALIDATION SPLIT
# ============================================================

def create_validation_split(
    dataframe: pd.DataFrame,
) -> tuple[
    pd.DataFrame,
    pd.DataFrame,
]:

    subject_labels = (
        dataframe[
            [
                GROUP_COLUMN,
                TARGET_COLUMN,
            ]
        ]
        .drop_duplicates(
            subset=[GROUP_COLUMN]
        )
    )

    random_generator = random.Random(
        RANDOM_STATE
    )

    training_subjects = set()

    validation_subjects = set()

    for label in sorted(
        subject_labels[
            TARGET_COLUMN
        ].unique()
    ):

        subjects = (
            subject_labels[
                subject_labels[
                    TARGET_COLUMN
                ] == label
            ][GROUP_COLUMN]
            .astype(str)
            .tolist()
        )

        random_generator.shuffle(
            subjects
        )

        validation_count = max(
            1,
            round(
                len(subjects)
                * VALIDATION_SIZE
            ),
        )

        if validation_count >= len(subjects):
            validation_count = max(
                1,
                len(subjects) - 1,
            )

        validation_class_subjects = set(
            subjects[
                :validation_count
            ]
        )

        training_class_subjects = set(
            subjects[
                validation_count:
            ]
        )

        validation_subjects.update(
            validation_class_subjects
        )

        training_subjects.update(
            training_class_subjects
        )

    training_dataframe = dataframe[
        dataframe[
            GROUP_COLUMN
        ].astype(str).isin(
            training_subjects
        )
    ].copy()

    validation_dataframe = dataframe[
        dataframe[
            GROUP_COLUMN
        ].astype(str).isin(
            validation_subjects
        )
    ].copy()

    if training_dataframe.empty:
        raise RuntimeError(
            "Subject-level training split "
            "is empty."
        )

    if validation_dataframe.empty:
        raise RuntimeError(
            "Subject-level validation split "
            "is empty."
        )

    return (
        training_dataframe,
        validation_dataframe,
    )


# ============================================================
# LOGISTIC REGRESSION
# ============================================================

def train_logistic_regression(
    x: np.ndarray,
    y: np.ndarray,
) -> tuple[
    np.ndarray,
    float,
]:

    sample_count, feature_count = (
        x.shape
    )

    weights = np.zeros(
        feature_count,
        dtype=float,
    )

    bias = 0.0

    positive_count = np.sum(
        y == 1
    )

    negative_count = np.sum(
        y == 0
    )

    if (
        positive_count == 0
        or negative_count == 0
    ):
        raise RuntimeError(
            "Training data must contain "
            "both classes."
        )

    positive_weight = (
        sample_count
        / (
            2.0
            * positive_count
        )
    )

    negative_weight = (
        sample_count
        / (
            2.0
            * negative_count
        )
    )

    sample_weights = np.where(
        y == 1,
        positive_weight,
        negative_weight,
    )

    for _ in range(EPOCHS):

        logits = (
            x @ weights
            + bias
        )

        probabilities = sigmoid(
            logits
        )

        errors = (
            probabilities - y
        )

        weighted_errors = (
            sample_weights
            * errors
        )

        gradient_weights = (
            x.T
            @ weighted_errors
            / sample_count
        )

        gradient_weights += (
            L2_STRENGTH
            * weights
        )

        gradient_bias = (
            np.sum(
                weighted_errors
            )
            / sample_count
        )

        weights -= (
            LEARNING_RATE
            * gradient_weights
        )

        bias -= (
            LEARNING_RATE
            * gradient_bias
        )

    return (
        weights,
        bias,
    )


# ============================================================
# METRICS
# ============================================================

def calculate_metrics(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    threshold: float,
) -> dict[str, float | int]:

    predictions = (
        probabilities >= threshold
    ).astype(int)

    true_negative = int(
        np.sum(
            (y_true == 0)
            & (predictions == 0)
        )
    )

    false_positive = int(
        np.sum(
            (y_true == 0)
            & (predictions == 1)
        )
    )

    false_negative = int(
        np.sum(
            (y_true == 1)
            & (predictions == 0)
        )
    )

    true_positive = int(
        np.sum(
            (y_true == 1)
            & (predictions == 1)
        )
    )

    sensitivity = (
        true_positive
        / (
            true_positive
            + false_negative
        )
        if (
            true_positive
            + false_negative
        ) > 0
        else 0.0
    )

    specificity = (
        true_negative
        / (
            true_negative
            + false_positive
        )
        if (
            true_negative
            + false_positive
        ) > 0
        else 0.0
    )

    precision = (
        true_positive
        / (
            true_positive
            + false_positive
        )
        if (
            true_positive
            + false_positive
        ) > 0
        else 0.0
    )

    f1 = (
        2.0
        * precision
        * sensitivity
        / (
            precision
            + sensitivity
        )
        if (
            precision
            + sensitivity
        ) > 0
        else 0.0
    )

    accuracy = float(
        np.mean(
            y_true == predictions
        )
    )

    youden_j = (
        sensitivity
        + specificity
        - 1.0
    )

    return {
        "threshold": float(
            threshold
        ),
        "sensitivity": float(
            sensitivity
        ),
        "specificity": float(
            specificity
        ),
        "precision": float(
            precision
        ),
        "f1": float(f1),
        "accuracy": float(
            accuracy
        ),
        "youden_j": float(
            youden_j
        ),
        "true_negative":
            true_negative,
        "false_positive":
            false_positive,
        "false_negative":
            false_negative,
        "true_positive":
            true_positive,
    }


def calculate_auc(
    y_true: np.ndarray,
    probabilities: np.ndarray,
) -> float:

    positive_scores = (
        probabilities[
            y_true == 1
        ]
    )

    negative_scores = (
        probabilities[
            y_true == 0
        ]
    )

    if (
        len(positive_scores) == 0
        or len(negative_scores) == 0
    ):
        return 0.0

    comparisons = (
        positive_scores[:, None]
        > negative_scores[None, :]
    )

    ties = (
        positive_scores[:, None]
        == negative_scores[None, :]
    )

    auc = (
        np.sum(comparisons)
        + 0.5 * np.sum(ties)
    ) / (
        len(positive_scores)
        * len(negative_scores)
    )

    return float(auc)


# ============================================================
# THRESHOLD SELECTION
# ============================================================

def select_threshold(
    validation_results: pd.DataFrame,
) -> tuple[
    float,
    str,
]:

    candidates = (
        validation_results[
            validation_results[
                "sensitivity"
            ]
            >= TARGET_SENSITIVITY
        ]
    )

    if not candidates.empty:

        selected = (
            candidates
            .sort_values(
                by=[
                    "specificity",
                    "f1",
                    "threshold",
                ],
                ascending=[
                    False,
                    False,
                    True,
                ],
            )
            .iloc[0]
        )

        return (
            float(
                selected[
                    "threshold"
                ]
            ),
            (
                "Highest validation "
                "specificity among "
                "thresholds achieving "
                f"at least "
                f"{TARGET_SENSITIVITY:.0%} "
                "sensitivity."
            ),
        )

    selected = (
        validation_results
        .sort_values(
            by=[
                "youden_j",
                "sensitivity",
                "specificity",
            ],
            ascending=[
                False,
                False,
                False,
            ],
        )
        .iloc[0]
    )

    return (
        float(
            selected[
                "threshold"
            ]
        ),
        (
            "No threshold achieved "
            f"{TARGET_SENSITIVITY:.0%} "
            "validation sensitivity; "
            "selected the threshold "
            "with the highest Youden J."
        ),
    )


# ============================================================
# MODEL EXPORT
# ============================================================

def build_model_artifact(
    means: np.ndarray,
    standard_deviations: np.ndarray,
    weights: np.ndarray,
    bias: float,
    threshold: float,
) -> dict:

    return {
        "model_type":
            MODEL_TYPE,

        "model_version":
            MODEL_VERSION,

        "target_column":
            TARGET_COLUMN,

        "feature_schema":
            FEATURE_SCHEMA,

        "feature_columns":
            FEATURE_COLUMNS,

        "standardization": {
            "method":
                "z_score_training_set",
            "means":
                means.tolist(),
            "standard_deviations":
                standard_deviations.tolist(),
        },

        "weights":
            weights.tolist(),

        "bias":
            float(bias),

        "screening": {
            "threshold":
                float(threshold),
            "target_sensitivity":
                TARGET_SENSITIVITY,
            "selection_method":
                "subject_level_validation",
        },

        "training": {
            "algorithm":
                "weighted_logistic_regression",
            "learning_rate":
                LEARNING_RATE,
            "epochs":
                EPOCHS,
            "l2_strength":
                L2_STRENGTH,
            "random_state":
                RANDOM_STATE,
        },
    }


# ============================================================
# MAIN TRAINING PIPELINE
# ============================================================

def main() -> None:

    print()
    print(
        "Hardware 31-Feature "
        "OA Screening Model"
    )
    print("=" * 70)

    if not TRAIN_FILE.exists():
        raise FileNotFoundError(
            f"\nTraining file not found:\n"
            f"{TRAIN_FILE}\n\n"
            "Create hardware_31_train.csv "
            "with the canonical 31 features "
            "and oa_label before training."
        )

    if not TEST_FILE.exists():
        raise FileNotFoundError(
            f"\nTest file not found:\n"
            f"{TEST_FILE}\n\n"
            "Create hardware_31_test.csv "
            "with the canonical 31 features "
            "and oa_label before training."
        )

    train_dataframe = pd.read_csv(
        TRAIN_FILE
    )

    test_dataframe = pd.read_csv(
        TEST_FILE
    )

    print(
        f"Training rows: "
        f"{len(train_dataframe)}"
    )

    print(
        f"Test rows: "
        f"{len(test_dataframe)}"
    )

    print(
        f"Features: "
        f"{len(FEATURE_COLUMNS)}"
    )

    validate_dataframe(
        train_dataframe,
        TRAIN_FILE.name,
    )

    validate_dataframe(
        test_dataframe,
        TEST_FILE.name,
    )

    validate_subject_labels(
        train_dataframe
    )

    validate_subject_labels(
        test_dataframe
    )

    print()
    print(
        "Data validation passed."
    )

    print(
        "Canonical schema: "
        f"{FEATURE_SCHEMA}"
    )

    print()

    (
        model_dataframe,
        validation_dataframe,
    ) = create_validation_split(
        train_dataframe
    )

    print(
        "SUBJECT-LEVEL VALIDATION SPLIT"
    )
    print("-" * 70)

    print(
        f"Model-training rows: "
        f"{len(model_dataframe)}"
    )

    print(
        f"Model-training subjects: "
        f"{model_dataframe[GROUP_COLUMN].nunique()}"
    )

    print(
        f"Validation rows: "
        f"{len(validation_dataframe)}"
    )

    print(
        f"Validation subjects: "
        f"{validation_dataframe[GROUP_COLUMN].nunique()}"
    )

    print()

    print(
        "Model-training class "
        "distribution:"
    )

    print(
        model_dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()

    print(
        "Validation class "
        "distribution:"
    )

    print(
        validation_dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    x_model = (
        model_dataframe[
            FEATURE_COLUMNS
        ]
        .to_numpy(
            dtype=float
        )
    )

    x_validation = (
        validation_dataframe[
            FEATURE_COLUMNS
        ]
        .to_numpy(
            dtype=float
        )
    )

    y_model = (
        model_dataframe[
            TARGET_COLUMN
        ]
        .to_numpy(
            dtype=int
        )
    )

    y_validation = (
        validation_dataframe[
            TARGET_COLUMN
        ]
        .to_numpy(
            dtype=int
        )
    )

    print()
    print(
        "Standardizing model-training "
        "data..."
    )

    (
        x_model,
        x_validation,
        _,
        _,
    ) = standardize_train_other(
        x_model,
        x_validation,
    )

    print(
        "Training temporary validation "
        "model..."
    )

    validation_weights, validation_bias = (
        train_logistic_regression(
            x_model,
            y_model,
        )
    )

    validation_probabilities = sigmoid(
        x_validation
        @ validation_weights
        + validation_bias
    )

    print(
        "Validation predictions "
        "generated."
    )

    print()
    print(
        "VALIDATION THRESHOLD ANALYSIS"
    )
    print("=" * 70)

    threshold_results = []

    thresholds = np.arange(
        0.10,
        0.91,
        THRESHOLD_STEP,
    )

    for threshold in thresholds:

        metrics = calculate_metrics(
            y_validation,
            validation_probabilities,
            float(threshold),
        )

        threshold_results.append(
            metrics
        )

        print(
            f"Threshold={threshold:.2f} "
            f"| Sensitivity="
            f"{metrics['sensitivity']:.4f} "
            f"| Specificity="
            f"{metrics['specificity']:.4f} "
            f"| F1="
            f"{metrics['f1']:.4f}"
        )

    validation_results = pd.DataFrame(
        threshold_results
    )

    (
        selected_threshold,
        selection_reason,
    ) = select_threshold(
        validation_results
    )

    print()
    print(
        "SELECTED SCREENING THRESHOLD"
    )
    print("=" * 70)

    print(
        f"Threshold: "
        f"{selected_threshold:.2f}"
    )

    print(
        f"Reason: "
        f"{selection_reason}"
    )

    selected_validation_metrics = (
        validation_results[
            validation_results[
                "threshold"
            ]
            == selected_threshold
        ]
        .iloc[0]
    )

    print()

    print(
        "Validation performance:"
    )

    print(
        f"Sensitivity: "
        f"{selected_validation_metrics['sensitivity']:.4f}"
    )

    print(
        f"Specificity: "
        f"{selected_validation_metrics['specificity']:.4f}"
    )

    print(
        f"Precision:   "
        f"{selected_validation_metrics['precision']:.4f}"
    )

    print(
        f"F1:          "
        f"{selected_validation_metrics['f1']:.4f}"
    )

    # --------------------------------------------------------
    # FINAL MODEL
    # --------------------------------------------------------

    print()
    print(
        "RETRAINING FINAL MODEL"
    )
    print("=" * 70)

    x_train_full = (
        train_dataframe[
            FEATURE_COLUMNS
        ]
        .to_numpy(
            dtype=float
        )
    )

    x_test = (
        test_dataframe[
            FEATURE_COLUMNS
        ]
        .to_numpy(
            dtype=float
        )
    )

    y_train_full = (
        train_dataframe[
            TARGET_COLUMN
        ]
        .to_numpy(
            dtype=int
        )
    )

    y_test = (
        test_dataframe[
            TARGET_COLUMN
        ]
        .to_numpy(
            dtype=int
        )
    )

    (
        x_train_full,
        x_test,
        means,
        standard_deviations,
    ) = standardize_train_other(
        x_train_full,
        x_test,
    )

    final_weights, final_bias = (
        train_logistic_regression(
            x_train_full,
            y_train_full,
        )
    )

    test_probabilities = sigmoid(
        x_test
        @ final_weights
        + final_bias
    )

    test_metrics = calculate_metrics(
        y_test,
        test_probabilities,
        selected_threshold,
    )

    test_auc = calculate_auc(
        y_test,
        test_probabilities,
    )

    print(
        "Final unseen-test performance"
    )

    print(
        f"Sensitivity: "
        f"{test_metrics['sensitivity']:.4f}"
    )

    print(
        f"Specificity: "
        f"{test_metrics['specificity']:.4f}"
    )

    print(
        f"Precision:   "
        f"{test_metrics['precision']:.4f}"
    )

    print(
        f"F1:          "
        f"{test_metrics['f1']:.4f}"
    )

    print(
        f"Accuracy:    "
        f"{test_metrics['accuracy']:.4f}"
    )

    print(
        f"ROC-AUC:     "
        f"{test_auc:.4f}"
    )

    # --------------------------------------------------------
    # EXPORT MODEL
    # --------------------------------------------------------

    artifact = build_model_artifact(
        means=means,
        standard_deviations=
            standard_deviations,
        weights=final_weights,
        bias=final_bias,
        threshold=selected_threshold,
    )

    MODEL_OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with MODEL_OUTPUT_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            artifact,
            file,
            indent=2,
        )

    metrics_artifact = {
        "model_version":
            MODEL_VERSION,

        "feature_schema":
            FEATURE_SCHEMA,

        "feature_count":
            len(FEATURE_COLUMNS),

        "training_rows":
            len(train_dataframe),

        "training_subjects":
            int(
                train_dataframe[
                    GROUP_COLUMN
                ].nunique()
            ),

        "test_rows":
            len(test_dataframe),

        "test_subjects":
            int(
                test_dataframe[
                    GROUP_COLUMN
                ].nunique()
            ),

        "screening_threshold":
            selected_threshold,

        "validation": {
            "sensitivity":
                float(
                    selected_validation_metrics[
                        "sensitivity"
                    ]
                ),
            "specificity":
                float(
                    selected_validation_metrics[
                        "specificity"
                    ]
                ),
            "precision":
                float(
                    selected_validation_metrics[
                        "precision"
                    ]
                ),
            "f1":
                float(
                    selected_validation_metrics[
                        "f1"
                    ]
                ),
            "accuracy":
                float(
                    selected_validation_metrics[
                        "accuracy"
                    ]
                ),
        },

        "unseen_test": {
            "sensitivity":
                test_metrics[
                    "sensitivity"
                ],
            "specificity":
                test_metrics[
                    "specificity"
                ],
            "precision":
                test_metrics[
                    "precision"
                ],
            "f1":
                test_metrics[
                    "f1"
                ],
            "accuracy":
                test_metrics[
                    "accuracy"
                ],
            "roc_auc":
                test_auc,
        },
    }

    with METRICS_OUTPUT_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            metrics_artifact,
            file,
            indent=2,
        )

    print()
    print(
        "MODEL EXPORTED"
    )
    print("=" * 70)

    print(
        f"Model:"
        f"\n  {MODEL_OUTPUT_FILE}"
    )

    print(
        f"Metrics:"
        f"\n  {METRICS_OUTPUT_FILE}"
    )

    print()
    print(
        "Hardware 31-feature model "
        "training complete."
    )


if __name__ == "__main__":
    main()