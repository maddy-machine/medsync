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


RANDOM_STATE = 42

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
        means,
        standard_deviations,
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
        if positive_count > 0
        else 1.0
    )

    negative_weight = (
        sample_count
        / (2.0 * negative_count)
        if negative_count > 0
        else 1.0
    )

    sample_weights = np.where(
        y == 1,
        positive_weight,
        negative_weight,
    )

    for epoch in range(EPOCHS):
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

        if (
            epoch == 0
            or (epoch + 1) % 500 == 0
        ):
            probabilities_clipped = np.clip(
                probabilities,
                1e-12,
                1.0 - 1e-12,
            )

            loss = -np.mean(
                sample_weights
                * (
                    y
                    * np.log(
                        probabilities_clipped
                    )
                    + (
                        1 - y
                    )
                    * np.log(
                        1
                        - probabilities_clipped
                    )
                )
            )

            loss += (
                L2_STRENGTH
                * np.sum(
                    weights * weights
                )
                / 2.0
            )

            print(
                f"Epoch {epoch + 1:4d} "
                f"| loss={loss:.6f}"
            )

    return weights, bias


def calculate_accuracy(
    y_true: np.ndarray,
    y_pred: np.ndarray,
) -> float:
    if len(y_true) == 0:
        return 0.0

    return float(
        np.mean(
            y_true == y_pred
        )
    )


def calculate_confusion_matrix(
    y_true: np.ndarray,
    y_pred: np.ndarray,
) -> tuple[int, int, int, int]:
    true_negative = int(
        np.sum(
            (y_true == 0)
            & (y_pred == 0)
        )
    )

    false_positive = int(
        np.sum(
            (y_true == 0)
            & (y_pred == 1)
        )
    )

    false_negative = int(
        np.sum(
            (y_true == 1)
            & (y_pred == 0)
        )
    )

    true_positive = int(
        np.sum(
            (y_true == 1)
            & (y_pred == 1)
        )
    )

    return (
        true_negative,
        false_positive,
        false_negative,
        true_positive,
    )


def calculate_metrics(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    threshold: float = 0.5,
) -> dict[str, float | int]:
    predictions = (
        probabilities >= threshold
    ).astype(int)

    (
        true_negative,
        false_positive,
        false_negative,
        true_positive,
    ) = calculate_confusion_matrix(
        y_true,
        predictions,
    )

    accuracy = calculate_accuracy(
        y_true,
        predictions,
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

    return {
        "accuracy": accuracy,
        "sensitivity": sensitivity,
        "specificity": specificity,
        "precision": precision,
        "f1": f1,
        "true_negative": true_negative,
        "false_positive": false_positive,
        "false_negative": false_negative,
        "true_positive": true_positive,
    }


def calculate_auc(
    y_true: np.ndarray,
    probabilities: np.ndarray,
) -> float:
    positive_count = int(
        np.sum(y_true == 1)
    )

    negative_count = int(
        np.sum(y_true == 0)
    )

    if (
        positive_count == 0
        or negative_count == 0
    ):
        return 0.0

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
        positive_count
        * negative_count
    )

    return float(auc)


def get_feature_columns(
    dataframe: pd.DataFrame,
) -> list[str]:
    return [
        column
        for column in dataframe.columns
        if column not in IDENTIFIER_COLUMNS
        and column != TARGET_COLUMN
    ]


def main() -> None:
    print(
        "Baseline Logistic Regression"
    )
    print("=" * 60)

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

    train_dataframe = pd.read_csv(
        TRAIN_FILE
    )

    test_dataframe = pd.read_csv(
        TEST_FILE
    )

    feature_columns = (
        get_feature_columns(
            train_dataframe
        )
    )

    print(
        f"Training trials: "
        f"{len(train_dataframe)}"
    )

    print(
        f"Test trials: "
        f"{len(test_dataframe)}"
    )

    print(
        f"Features: "
        f"{len(feature_columns)}"
    )

    print()

    x_train = (
        train_dataframe[
            feature_columns
        ]
        .to_numpy(
            dtype=float
        )
    )

    x_test = (
        test_dataframe[
            feature_columns
        ]
        .to_numpy(
            dtype=float
        )
    )

    y_train = (
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
        x_train,
        x_test,
        means,
        standard_deviations,
    ) = standardize_train_test(
        x_train,
        x_test,
    )

    print(
        "Training feature standardization "
        "completed."
    )

    print(
        "Important: test data uses "
        "training-set statistics only."
    )

    print()

    print(
        "Training model..."
    )

    weights, bias = (
        train_logistic_regression(
            x_train,
            y_train,
        )
    )

    print()

    train_probabilities = sigmoid(
        x_train @ weights
        + bias
    )

    test_probabilities = sigmoid(
        x_test @ weights
        + bias
    )

    train_metrics = calculate_metrics(
        y_train,
        train_probabilities,
    )

    test_metrics = calculate_metrics(
        y_test,
        test_probabilities,
    )

    test_auc = calculate_auc(
        y_test,
        test_probabilities,
    )

    print(
        "=" * 60
    )

    print(
        "TRAINING PERFORMANCE"
    )

    print(
        f"Accuracy:     "
        f"{train_metrics['accuracy']:.4f}"
    )

    print(
        f"Sensitivity:  "
        f"{train_metrics['sensitivity']:.4f}"
    )

    print(
        f"Specificity:  "
        f"{train_metrics['specificity']:.4f}"
    )

    print(
        f"Precision:    "
        f"{train_metrics['precision']:.4f}"
    )

    print(
        f"F1:           "
        f"{train_metrics['f1']:.4f}"
    )

    print()

    print(
        "UNSEEN TEST SUBJECT PERFORMANCE"
    )

    print(
        f"Accuracy:     "
        f"{test_metrics['accuracy']:.4f}"
    )

    print(
        f"Sensitivity:  "
        f"{test_metrics['sensitivity']:.4f}"
    )

    print(
        f"Specificity:  "
        f"{test_metrics['specificity']:.4f}"
    )

    print(
        f"Precision:    "
        f"{test_metrics['precision']:.4f}"
    )

    print(
        f"F1:           "
        f"{test_metrics['f1']:.4f}"
    )

    print(
        f"ROC-AUC:      "
        f"{test_auc:.4f}"
    )

    print()

    print(
        "CONFUSION MATRIX"
    )

    print(
        "                 Predicted"
    )

    print(
        "                 Healthy   KOA"
    )

    print(
        f"Actual Healthy  "
        f"{test_metrics['true_negative']:8d}"
        f" {test_metrics['false_positive']:5d}"
    )

    print(
        f"Actual KOA      "
        f"{test_metrics['false_negative']:8d}"
        f" {test_metrics['true_positive']:5d}"
    )

    print()

    print(
        "Model training complete."
    )


if __name__ == "__main__":
    main()