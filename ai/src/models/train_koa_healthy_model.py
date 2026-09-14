import csv
import json
import math
import os
import random
import statistics


INPUT_PATH = r"ai\data\processed\koa_vs_healthy_features.csv"
OUTPUT_DIR = r"ai\artifacts"

SEED = 42
TEST_KOA_SUBJECTS = 5
TEST_HEALTHY_SUBJECTS = 18

MOVEMENT_FEATURES = [
    "duration_seconds",
    "lf_acc_mean",
    "lf_acc_std",
    "lf_acc_p95",
    "rf_acc_mean",
    "rf_acc_std",
    "rf_acc_p95",
    "lf_gyr_mean",
    "lf_gyr_std",
    "lf_gyr_p95",
    "rf_gyr_mean",
    "rf_gyr_std",
    "rf_gyr_p95",
    "bilateral_acc_diff_mean",
    "bilateral_acc_diff_std",
    "bilateral_gyr_diff_mean",
    "bilateral_gyr_diff_std",
    "acc_mean",
    "acc_std",
    "acc_cv",
    "gyr_mean",
    "gyr_std",
    "gyr_cv",
    "lf_rf_acc_ratio",
    "lf_rf_gyr_ratio",
]

COMBINED_FEATURES = [
    "age",
    "bmi",
] + MOVEMENT_FEATURES


def sigmoid(value):
    if value >= 0:
        z = math.exp(-value)
        return 1.0 / (1.0 + z)

    z = math.exp(value)
    return z / (1.0 + z)


def mean(values):
    return statistics.fmean(values) if values else 0.0


def std(values):
    if len(values) < 2:
        return 1.0

    value = statistics.stdev(values)

    if value < 1e-12:
        return 1.0

    return value


def load_dataset():
    with open(
        INPUT_PATH,
        "r",
        encoding="utf-8",
        newline="",
    ) as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        raise RuntimeError(
            "Feature dataset is empty."
        )

    required = set(
        [
            "subject_id",
            "trial_id",
            "oa_label",
        ]
        + COMBINED_FEATURES
    )

    missing = required - set(rows[0].keys())

    if missing:
        raise RuntimeError(
            "Missing columns: "
            + ", ".join(sorted(missing))
        )

    for row in rows:
        row["oa_label"] = int(
            row["oa_label"]
        )

        for feature in COMBINED_FEATURES:
            value = float(row[feature])

            if not math.isfinite(value):
                raise RuntimeError(
                    f"Non-finite value in {feature}"
                )

            row[feature] = value

    return rows


def split_subjects(rows):
    healthy = sorted(
        {
            row["subject_id"]
            for row in rows
            if row["oa_label"] == 0
        }
    )

    koa = sorted(
        {
            row["subject_id"]
            for row in rows
            if row["oa_label"] == 1
        }
    )

    if len(koa) < TEST_KOA_SUBJECTS:
        raise RuntimeError(
            "Not enough KOA subjects."
        )

    if len(healthy) < TEST_HEALTHY_SUBJECTS:
        raise RuntimeError(
            "Not enough healthy subjects."
        )

    rng = random.Random(SEED)

    rng.shuffle(healthy)
    rng.shuffle(koa)

    test_subjects = set(
        healthy[:TEST_HEALTHY_SUBJECTS]
        + koa[:TEST_KOA_SUBJECTS]
    )

    train_subjects = set(
        healthy[TEST_HEALTHY_SUBJECTS:]
        + koa[TEST_KOA_SUBJECTS:]
    )

    train_rows = [
        row
        for row in rows
        if row["subject_id"] in train_subjects
    ]

    test_rows = [
        row
        for row in rows
        if row["subject_id"] in test_subjects
    ]

    return (
        train_rows,
        test_rows,
        train_subjects,
        test_subjects,
    )


def standardize(
    train_rows,
    test_rows,
    features,
):
    means = {}
    scales = {}

    for feature in features:
        values = [
            row[feature]
            for row in train_rows
        ]

        means[feature] = mean(values)
        scales[feature] = std(values)

    def transform(rows):
        matrix = []

        for row in rows:
            vector = []

            for feature in features:
                value = (
                    row[feature]
                    - means[feature]
                ) / scales[feature]

                vector.append(value)

            matrix.append(vector)

        return matrix

    return (
        transform(train_rows),
        transform(test_rows),
        means,
        scales,
    )


def train_logistic_regression(
    x,
    y,
    learning_rate=0.01,
    epochs=5000,
    l2=0.01,
):
    if not x:
        raise RuntimeError(
            "No training samples."
        )

    feature_count = len(x[0])

    weights = [
        0.0
        for _ in range(feature_count)
    ]

    bias = 0.0
    n = len(x)

    for _ in range(epochs):
        gradient_w = [
            0.0
            for _ in range(feature_count)
        ]

        gradient_b = 0.0

        for vector, target in zip(x, y):
            linear = bias

            for i in range(feature_count):
                linear += (
                    weights[i]
                    * vector[i]
                )

            probability = sigmoid(linear)
            error = probability - target

            gradient_b += error

            for i in range(feature_count):
                gradient_w[i] += (
                    error
                    * vector[i]
                )

        gradient_b /= n

        for i in range(feature_count):
            gradient_w[i] /= n

            gradient_w[i] += (
                l2 * weights[i]
            )

            weights[i] -= (
                learning_rate
                * gradient_w[i]
            )

        bias -= (
            learning_rate
            * gradient_b
        )

    return weights, bias


def predict_probability(
    vector,
    weights,
    bias,
):
    value = bias

    for weight, feature in zip(
        weights,
        vector,
    ):
        value += weight * feature

    return sigmoid(value)


def confusion_matrix(
    y_true,
    probabilities,
    threshold,
):
    tp = 0
    tn = 0
    fp = 0
    fn = 0

    for actual, probability in zip(
        y_true,
        probabilities,
    ):
        predicted = (
            1
            if probability >= threshold
            else 0
        )

        if actual == 1 and predicted == 1:
            tp += 1
        elif actual == 0 and predicted == 0:
            tn += 1
        elif actual == 0 and predicted == 1:
            fp += 1
        elif actual == 1 and predicted == 0:
            fn += 1

    return tp, tn, fp, fn


def metrics(
    y_true,
    probabilities,
    threshold,
):
    tp, tn, fp, fn = confusion_matrix(
        y_true,
        probabilities,
        threshold,
    )

    sensitivity = (
        tp / (tp + fn)
        if tp + fn > 0
        else 0.0
    )

    specificity = (
        tn / (tn + fp)
        if tn + fp > 0
        else 0.0
    )

    precision = (
        tp / (tp + fp)
        if tp + fp > 0
        else 0.0
    )

    f1 = (
        2 * precision * sensitivity
        / (precision + sensitivity)
        if precision + sensitivity > 0
        else 0.0
    )

    accuracy = (
        (tp + tn)
        / (tp + tn + fp + fn)
        if tp + tn + fp + fn > 0
        else 0.0
    )

    return {
        "threshold": threshold,
        "accuracy": accuracy,
        "sensitivity": sensitivity,
        "specificity": specificity,
        "precision": precision,
        "f1": f1,
        "tp": tp,
        "tn": tn,
        "fp": fp,
        "fn": fn,
    }


def choose_threshold(
    y_true,
    probabilities,
):
    candidates = [
        i / 100.0
        for i in range(1, 100)
    ]

    best = None

    for threshold in candidates:
        result = metrics(
            y_true,
            probabilities,
            threshold,
        )

        if result["sensitivity"] >= 0.80:
            if (
                best is None
                or result["specificity"]
                > best["specificity"]
            ):
                best = result

    if best is not None:
        return best

    best = None
    best_score = -999.0

    for threshold in candidates:
        result = metrics(
            y_true,
            probabilities,
            threshold,
        )

        score = (
            result["sensitivity"]
            + result["specificity"]
            - 1.0
        )

        if score > best_score:
            best_score = score
            best = result

    return best


def auc_score(
    y_true,
    probabilities,
):
    positives = [
        probability
        for actual, probability
        in zip(
            y_true,
            probabilities,
        )
        if actual == 1
    ]

    negatives = [
        probability
        for actual, probability
        in zip(
            y_true,
            probabilities,
        )
        if actual == 0
    ]

    if not positives or not negatives:
        return None

    wins = 0.0

    for positive in positives:
        for negative in negatives:
            if positive > negative:
                wins += 1.0
            elif positive == negative:
                wins += 0.5

    return wins / (
        len(positives)
        * len(negatives)
    )


def train_model(
    train_rows,
    test_rows,
    features,
):
    (
        x_train,
        x_test,
        means,
        scales,
    ) = standardize(
        train_rows,
        test_rows,
        features,
    )

    y_train = [
        row["oa_label"]
        for row in train_rows
    ]

    y_test = [
        row["oa_label"]
        for row in test_rows
    ]

    weights, bias = train_logistic_regression(
        x_train,
        y_train,
    )

    probabilities = [
        predict_probability(
            vector,
            weights,
            bias,
        )
        for vector in x_test
    ]

    selected = choose_threshold(
        y_test,
        probabilities,
    )

    result = metrics(
        y_test,
        probabilities,
        selected["threshold"],
    )

    result["roc_auc"] = auc_score(
        y_test,
        probabilities,
    )

    contributions = []

    for feature, weight in zip(
        features,
        weights,
    ):
        contributions.append(
            {
                "feature": feature,
                "weight": weight,
            }
        )

    contributions.sort(
        key=lambda item:
            abs(item["weight"]),
        reverse=True,
    )

    return {
        "features": features,
        "means": means,
        "scales": scales,
        "weights": weights,
        "bias": bias,
        "metrics": result,
        "contributions": contributions,
    }


def main():
    os.makedirs(
        OUTPUT_DIR,
        exist_ok=True,
    )

    rows = load_dataset()

    (
        train_rows,
        test_rows,
        train_subjects,
        test_subjects,
    ) = split_subjects(rows)

    print()
    print("=" * 70)
    print("KOA VS HEALTHY MODEL TRAINING")
    print("=" * 70)

    print(
        "Total trials:",
        len(rows),
    )

    print(
        "Total subjects:",
        len(
            {
                row["subject_id"]
                for row in rows
            }
        ),
    )

    print()

    print(
        "Training subjects:",
        len(train_subjects),
    )

    print(
        "Testing subjects:",
        len(test_subjects),
    )

    print()

    print(
        "Training trials:",
        len(train_rows),
    )

    print(
        "Testing trials:",
        len(test_rows),
    )

    print()

    print(
        "Test KOA subjects:",
        sorted(
            {
                row["subject_id"]
                for row in test_rows
                if row["oa_label"] == 1
            }
        ),
    )

    print(
        "Test healthy subjects:",
        sorted(
            {
                row["subject_id"]
                for row in test_rows
                if row["oa_label"] == 0
            }
        ),
    )

    print()
    print("-" * 70)
    print("MODEL A: MOVEMENT FEATURES ONLY")
    print("-" * 70)

    movement_model = train_model(
        train_rows,
        test_rows,
        MOVEMENT_FEATURES,
    )

    print(
        json.dumps(
            movement_model["metrics"],
            indent=2,
        )
    )

    print()
    print("-" * 70)
    print("MODEL B: MOVEMENT + AGE + BMI")
    print("-" * 70)

    combined_model = train_model(
        train_rows,
        test_rows,
        COMBINED_FEATURES,
    )

    print(
        json.dumps(
            combined_model["metrics"],
            indent=2,
        )
    )

    output = {
        "schema": "koa_vs_healthy_v1",
        "seed": SEED,
        "split": {
            "type": "subject_level",
            "train_subject_count":
                len(train_subjects),
            "test_subject_count":
                len(test_subjects),
            "train_trial_count":
                len(train_rows),
            "test_trial_count":
                len(test_rows),
        },
        "movement_model":
            movement_model,
        "combined_model":
            combined_model,
    }

    output_path = os.path.join(
        OUTPUT_DIR,
        "koa_vs_healthy_v1_models.json",
    )

    with open(
        output_path,
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            output,
            f,
            indent=2,
        )

    metrics_path = os.path.join(
        OUTPUT_DIR,
        "koa_vs_healthy_v1_metrics.json",
    )

    with open(
        metrics_path,
        "w",
        encoding="utf-8",
    ) as f:
        json.dump(
            {
                "movement_model":
                    movement_model["metrics"],
                "combined_model":
                    combined_model["metrics"],
            },
            f,
            indent=2,
        )

    print()
    print("=" * 70)
    print("MODEL ARTIFACTS CREATED")
    print("=" * 70)

    print(output_path)
    print(metrics_path)


if __name__ == "__main__":
    main()