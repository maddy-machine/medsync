from pathlib import Path
import json
import random

import numpy as np
import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[2]

TRAIN_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_train.csv"
)

TEST_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_test.csv"
)

OUTPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "screening_threshold_selection.csv"
)

MODEL_OUTPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_logistic_regression_model.json"
)


TARGET_COLUMN = "oa_label"
GROUP_COLUMN = "subject_id"

IDENTIFIER_COLUMNS = [
    "subject_id",
    "trial_id",
    "pathology_key",
]

RANDOM_STATE = 42

VALIDATION_SIZE = 0.20

LEARNING_RATE = 0.01
EPOCHS = 3000
L2_STRENGTH = 0.01

# For a screening application we prioritize
# sensitivity. We first look for thresholds
# achieving at least 80% sensitivity on the
# validation subjects, then select the one with
# the highest specificity.
TARGET_SENSITIVITY = 0.80

THRESHOLD_STEP = 0.05


def sigmoid(
    values: np.ndarray,
) -> np.ndarray:
    values = np.clip(
        values,
        -500,
        500,
    )

    return 1.0 / (
        1.0 + np.exp(-values)
    )


def calculate_standardization_parameters(
    x_train: np.ndarray,
) -> tuple[
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

    return (
        means,
        standard_deviations,
    )


def standardize_train_test(
    x_train: np.ndarray,
    x_other: np.ndarray,
) -> tuple[
    np.ndarray,
    np.ndarray,
]:
    means, standard_deviations = (
        calculate_standardization_parameters(
            x_train,
        )
    )

    standardized_train = (
        x_train - means
    ) / standard_deviations

    standardized_other = (
        x_other - means
    ) / standard_deviations

    return (
        standardized_train,
        standardized_other,
    )


def standardize_with_parameters(
    x: np.ndarray,
    means: np.ndarray,
    standard_deviations: np.ndarray,
) -> np.ndarray:
    return (
        x - means
    ) / standard_deviations


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
            "Training subset must contain "
            "both classes."
        )

    positive_weight = (
        sample_count
        / (2.0 * positive_count)
    )

    negative_weight = (
        sample_count
        / (2.0 * negative_count)
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

    return weights, bias


def calculate_metrics(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    threshold: float,
) -> dict[str, float]:
    predictions = (
        probabilities >= threshold
    ).astype(int)

    true_negative = np.sum(
        (y_true == 0)
        & (predictions == 0)
    )

    false_positive = np.sum(
        (y_true == 0)
        & (predictions == 1)
    )

    false_negative = np.sum(
        (y_true == 1)
        & (predictions == 0)
    )

    true_positive = np.sum(
        (y_true == 1)
        & (predictions == 1)
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

    accuracy = np.mean(
        y_true == predictions
    )

    youden_j = (
        sensitivity
        + specificity
        - 1.0
    )

    return {
        "threshold": float(threshold),
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
    }


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

    return (
        training_dataframe,
        validation_dataframe,
    )


def select_threshold(
    validation_results: pd.DataFrame,
) -> tuple[
    float,
    str,
]:
    sensitivity_candidates = (
        validation_results[
            validation_results[
                "sensitivity"
            ]
            >= TARGET_SENSITIVITY
        ]
    )

    if not sensitivity_candidates.empty:
        selected = (
            sensitivity_candidates
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
                "at least "
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


def evaluate_locked_threshold(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    threshold: float,
) -> dict[str, float]:
    return calculate_metrics(
        y_true,
        probabilities,
        threshold,
    )


def save_model_artifact(
    feature_columns: list[str],
    means: np.ndarray,
    standard_deviations: np.ndarray,
    weights: np.ndarray,
    bias: float,
    threshold: float,
) -> None:
    artifact = {
        "model_type": "logistic_regression",
        "model_version": "oa_screening_v1",

        "target_column": TARGET_COLUMN,

        "feature_columns": feature_columns,

        "standardization": {
            "method": "z_score",
            "means": [
                float(value)
                for value in means
            ],
            "standard_deviations": [
                float(value)
                for value in standard_deviations
            ],
        },

        "weights": [
            float(value)
            for value in weights
        ],

        "bias": float(bias),

        "screening": {
            "threshold": float(threshold),
            "decision_rule": (
                "OA-associated risk when "
                "probability >= threshold"
            ),
        },

        "training_configuration": {
            "learning_rate": LEARNING_RATE,
            "epochs": EPOCHS,
            "l2_strength": L2_STRENGTH,
            "random_state": RANDOM_STATE,
        },
    }

    MODEL_OUTPUT_FILE.write_text(
        json.dumps(
            artifact,
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> None:
    print(
        "Subject-level screening "
        "threshold selection"
    )
    print("=" * 70)

    if not TRAIN_FILE.exists():
        raise FileNotFoundError(
            f"Training file not found:\n"
            f"{TRAIN_FILE}"
        )

    if not TEST_FILE.exists():
        raise FileNotFoundError(
            f"Test file not found:\n"
            f"{TEST_FILE}"
        )

    dataframe = pd.read_csv(
        TRAIN_FILE
    )

    test_dataframe = pd.read_csv(
        TEST_FILE
    )

    print(
        f"Original training trials: "
        f"{len(dataframe)}"
    )

    print(
        f"Original training subjects: "
        f"{dataframe[GROUP_COLUMN].nunique()}"
    )

    print()

    (
        model_dataframe,
        validation_dataframe,
    ) = create_validation_split(
        dataframe
    )

    print(
        "SUBJECT-LEVEL VALIDATION SPLIT"
    )

    print(
        f"Model-training trials: "
        f"{len(model_dataframe)}"
    )

    print(
        f"Model-training subjects: "
        f"{model_dataframe[GROUP_COLUMN].nunique()}"
    )

    print(
        f"Validation trials: "
        f"{len(validation_dataframe)}"
    )

    print(
        f"Validation subjects: "
        f"{validation_dataframe[GROUP_COLUMN].nunique()}"
    )

    print()

    print(
        "Model-training class distribution:"
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
        "Validation class distribution:"
    )

    print(
        validation_dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    feature_columns = [
        column
        for column in dataframe.columns
        if column not in IDENTIFIER_COLUMNS
        and column != TARGET_COLUMN
    ]

    x_model = model_dataframe[
        feature_columns
    ].to_numpy(dtype=float)

    x_validation = (
        validation_dataframe[
            feature_columns
        ]
        .to_numpy(dtype=float)
    )

    y_model = model_dataframe[
        TARGET_COLUMN
    ].to_numpy(dtype=int)

    y_validation = (
        validation_dataframe[
            TARGET_COLUMN
        ].to_numpy(dtype=int)
    )

    print()

    print(
        "Training temporary validation model..."
    )

    (
        x_model,
        x_validation,
    ) = standardize_train_test(
        x_model,
        x_validation,
    )

    weights, bias = (
        train_logistic_regression(
            x_model,
            y_model,
        )
    )

    validation_probabilities = sigmoid(
        x_validation @ weights
        + bias
    )

    print(
        "Validation predictions generated."
    )

    print()

    print("=" * 70)
    print(
        "VALIDATION THRESHOLD ANALYSIS"
    )
    print("=" * 70)

    print(
        f"{'Threshold':>10} "
        f"{'Sensitivity':>13} "
        f"{'Specificity':>13} "
        f"{'Precision':>11} "
        f"{'F1':>8} "
        f"{'Accuracy':>10}"
    )

    print("-" * 70)

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
            f"{threshold:10.2f} "
            f"{metrics['sensitivity']:13.4f} "
            f"{metrics['specificity']:13.4f} "
            f"{metrics['precision']:11.4f} "
            f"{metrics['f1']:8.4f} "
            f"{metrics['accuracy']:10.4f}"
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

    print("=" * 70)
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
        "Validation performance at "
        "selected threshold:"
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

    print()

    # --------------------------------------------------
    # LOCK THE THRESHOLD
    #
    # From this point onward, validation data is
    # not used to change the threshold.
    # --------------------------------------------------

    print("=" * 70)
    print(
        "LOCKING THRESHOLD"
    )
    print("=" * 70)

    print(
        f"Locked screening threshold: "
        f"{selected_threshold:.2f}"
    )

    print(
        "The threshold will now be evaluated "
        "once on the completely unseen test "
        "subjects."
    )

    # --------------------------------------------------
    # Retrain using ALL original training subjects.
    # --------------------------------------------------

    x_train_full = dataframe[
        feature_columns
    ].to_numpy(dtype=float)

    x_test = test_dataframe[
        feature_columns
    ].to_numpy(dtype=float)

    y_train_full = dataframe[
        TARGET_COLUMN
    ].to_numpy(dtype=int)

    y_test = test_dataframe[
        TARGET_COLUMN
    ].to_numpy(dtype=int)

    # Calculate and preserve the exact
    # standardization parameters used by
    # the final deployable model.
    (
        final_means,
        final_standard_deviations,
    ) = calculate_standardization_parameters(
        x_train_full
    )

    x_train_full = (
        standardize_with_parameters(
            x_train_full,
            final_means,
            final_standard_deviations,
        )
    )

    x_test = (
        standardize_with_parameters(
            x_test,
            final_means,
            final_standard_deviations,
        )
    )

    print()

    print(
        "Retraining final model on "
        "all training subjects..."
    )

    final_weights, final_bias = (
        train_logistic_regression(
            x_train_full,
            y_train_full,
        )
    )

    test_probabilities = sigmoid(
        x_test @ final_weights
        + final_bias
    )

    test_metrics = (
        evaluate_locked_threshold(
            y_test,
            test_probabilities,
            selected_threshold,
        )
    )

    print(
        "Final test predictions generated."
    )

    print()

    print("=" * 70)
    print(
        "FINAL UNSEEN-TEST PERFORMANCE"
    )
    print("=" * 70)

    print(
        f"Locked threshold: "
        f"{selected_threshold:.2f}"
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

    # --------------------------------------------------
    # SAVE FINAL DEPLOYABLE MODEL
    #
    # This artifact contains everything required
    # to reproduce the final model inference:
    #
    # 1. Feature names and order
    # 2. Training means
    # 3. Training standard deviations
    # 4. Logistic-regression weights
    # 5. Bias
    # 6. Locked screening threshold
    # --------------------------------------------------

    save_model_artifact(
        feature_columns=feature_columns,
        means=final_means,
        standard_deviations=final_standard_deviations,
        weights=final_weights,
        bias=final_bias,
        threshold=selected_threshold,
    )

    print()

    print(
        "Saved deployable model artifact:"
    )

    print(
        f"  {MODEL_OUTPUT_FILE}"
    )

    validation_results[
        "selected_threshold"
    ] = (
        validation_results[
            "threshold"
        ]
        == selected_threshold
    )

    validation_results.to_csv(
        OUTPUT_FILE,
        index=False,
    )

    print()

    print(
        "Saved validation threshold analysis:"
    )

    print(
        f"  {OUTPUT_FILE}"
    )

    print()

    print("=" * 70)
    print(
        "THRESHOLD SELECTION COMPLETE"
    )
    print("=" * 70)


if __name__ == "__main__":
    main()