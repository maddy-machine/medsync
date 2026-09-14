from pathlib import Path

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

TARGET_COLUMN = "oa_label"

IDENTIFIER_COLUMNS = [
    "subject_id",
    "trial_id",
    "pathology_key",
]

LEARNING_RATE = 0.01
EPOCHS = 3000
L2_STRENGTH = 0.01


def sigmoid(values: np.ndarray) -> np.ndarray:
    values = np.clip(
        values,
        -500,
        500,
    )

    return 1.0 / (
        1.0 + np.exp(-values)
    )


def standardize_train_test(
    x_train: np.ndarray,
    x_test: np.ndarray,
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

    standardized_train = (
        x_train - means
    ) / standard_deviations

    standardized_test = (
        x_test - means
    ) / standard_deviations

    return (
        standardized_train,
        standardized_test,
    )


def train_logistic_regression(
    x: np.ndarray,
    y: np.ndarray,
) -> tuple[np.ndarray, float]:
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

    return {
        "accuracy": float(
            accuracy
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
    }


def main() -> None:
    print(
        "OA screening threshold analysis"
    )
    print("=" * 70)

    train_dataframe = pd.read_csv(
        TRAIN_FILE
    )

    test_dataframe = pd.read_csv(
        TEST_FILE
    )

    feature_columns = [
        column
        for column in train_dataframe.columns
        if column not in IDENTIFIER_COLUMNS
        and column != TARGET_COLUMN
    ]

    x_train = train_dataframe[
        feature_columns
    ].to_numpy(dtype=float)

    x_test = test_dataframe[
        feature_columns
    ].to_numpy(dtype=float)

    y_train = train_dataframe[
        TARGET_COLUMN
    ].to_numpy(dtype=int)

    y_test = test_dataframe[
        TARGET_COLUMN
    ].to_numpy(dtype=int)

    (
        x_train,
        x_test,
    ) = standardize_train_test(
        x_train,
        x_test,
    )

    print(
        "Training baseline model..."
    )

    weights, bias = (
        train_logistic_regression(
            x_train,
            y_train,
        )
    )

    test_probabilities = sigmoid(
        x_test @ weights
        + bias
    )

    print(
        "Model predictions generated."
    )

    print()
    print("=" * 70)
    print(
        "THRESHOLD PERFORMANCE"
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

    results = []

    thresholds = np.arange(
        0.10,
        0.91,
        0.05,
    )

    for threshold in thresholds:
        metrics = calculate_metrics(
            y_test,
            test_probabilities,
            float(threshold),
        )

        results.append(
            {
                "threshold":
                    float(threshold),
                **metrics,
            }
        )

        print(
            f"{threshold:10.2f} "
            f"{metrics['sensitivity']:13.4f} "
            f"{metrics['specificity']:13.4f} "
            f"{metrics['precision']:11.4f} "
            f"{metrics['f1']:8.4f} "
            f"{metrics['accuracy']:10.4f}"
        )

    results_dataframe = pd.DataFrame(
        results
    )

    output_file = (
        AI_ROOT
        / "data"
        / "processed"
        / "threshold_analysis.csv"
    )

    results_dataframe.to_csv(
        output_file,
        index=False,
    )

    print()
    print("=" * 70)

    best_f1_row = (
        results_dataframe.loc[
            results_dataframe[
                "f1"
            ].idxmax()
        ]
    )

    print(
        "BEST F1 THRESHOLD"
    )

    print(
        f"Threshold:   "
        f"{best_f1_row['threshold']:.2f}"
    )

    print(
        f"Sensitivity: "
        f"{best_f1_row['sensitivity']:.4f}"
    )

    print(
        f"Specificity: "
        f"{best_f1_row['specificity']:.4f}"
    )

    print(
        f"Precision:   "
        f"{best_f1_row['precision']:.4f}"
    )

    print(
        f"F1:          "
        f"{best_f1_row['f1']:.4f}"
    )

    print(
        f"Accuracy:    "
        f"{best_f1_row['accuracy']:.4f}"
    )

    print()
    print(
        "Saved threshold analysis:"
    )

    print(
        f"  {output_file}"
    )


if __name__ == "__main__":
    main()