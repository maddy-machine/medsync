from pathlib import Path

import numpy as np
import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[1]

FEATURE_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_features.csv"
)


IDENTIFIER_COLUMNS = {
    "subject_id",
    "trial_id",
    "pathology_key",
}


TARGET_COLUMN = "oa_label"


def main() -> None:
    print("OA feature dataset validation")
    print("=" * 60)

    if not FEATURE_FILE.exists():
        raise FileNotFoundError(
            f"Feature dataset not found:\n"
            f"{FEATURE_FILE}"
        )

    dataframe = pd.read_csv(
        FEATURE_FILE
    )

    print(
        f"Rows: {len(dataframe)}"
    )

    print(
        f"Columns: {len(dataframe.columns)}"
    )

    print()
    print("Target distribution:")
    print(
        dataframe[TARGET_COLUMN]
        .value_counts()
        .sort_index()
        .to_string()
    )

    # ---------------------------------------------------------
    # Missing values
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("MISSING VALUES")
    print("=" * 60)

    missing = (
        dataframe.isna()
        .sum()
        .sort_values(
            ascending=False
        )
    )

    missing_features = missing[
        missing > 0
    ]

    if missing_features.empty:
        print(
            "No missing values found."
        )
    else:
        print(
            missing_features.to_string()
        )

    # ---------------------------------------------------------
    # Infinite values
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("INFINITE VALUES")
    print("=" * 60)

    numeric_columns = (
        dataframe.select_dtypes(
            include=np.number
        ).columns
    )

    infinite_counts = {}

    for column in numeric_columns:
        count = int(
            np.isinf(
                dataframe[column]
                .to_numpy()
            ).sum()
        )

        if count > 0:
            infinite_counts[
                column
            ] = count

    if not infinite_counts:
        print(
            "No infinite values found."
        )
    else:
        for column, count in (
            infinite_counts.items()
        ):
            print(
                f"{column}: {count}"
            )

    # ---------------------------------------------------------
    # Constant features
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("CONSTANT FEATURES")
    print("=" * 60)

    feature_columns = [
        column
        for column in dataframe.columns
        if column not in IDENTIFIER_COLUMNS
        and column != TARGET_COLUMN
    ]

    constant_features = []

    for column in feature_columns:
        if (
            dataframe[column]
            .nunique(dropna=False)
            <= 1
        ):
            constant_features.append(
                column
            )

    if not constant_features:
        print(
            "No constant features found."
        )
    else:
        for column in constant_features:
            print(
                f"  {column}"
            )

    # ---------------------------------------------------------
    # Duplicate rows
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("DUPLICATE TRIALS")
    print("=" * 60)

    duplicate_trial_ids = (
        dataframe["trial_id"]
        .duplicated()
        .sum()
    )

    print(
        f"Duplicate trial IDs: "
        f"{duplicate_trial_ids}"
    )

    # ---------------------------------------------------------
    # Target leakage check
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("TARGET LEAKAGE CHECK")
    print("=" * 60)

    leakage_candidates = []

    for column in feature_columns:
        if (
            dataframe[column]
            .equals(
                dataframe[TARGET_COLUMN]
            )
        ):
            leakage_candidates.append(
                column
            )

    if not leakage_candidates:
        print(
            "No feature exactly matches "
            "the target."
        )
    else:
        print(
            "Potential leakage:"
        )

        for column in (
            leakage_candidates
        ):
            print(
                f"  {column}"
            )

    # ---------------------------------------------------------
    # Feature ranges
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("NUMERIC FEATURE SUMMARY")
    print("=" * 60)

    summary = (
        dataframe[
            feature_columns
        ]
        .select_dtypes(
            include=np.number
        )
        .describe()
        .T
    )

    display_columns = [
        "mean",
        "std",
        "min",
        "max",
    ]

    print(
        summary[
            display_columns
        ].round(4).to_string()
    )

    # ---------------------------------------------------------
    # Subject counts
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("SUBJECT COUNTS BY CLASS")
    print("=" * 60)

    subject_counts = (
        dataframe.groupby(
            TARGET_COLUMN
        )["subject_id"]
        .nunique()
    )

    print(
        subject_counts.to_string()
    )

    # ---------------------------------------------------------
    # Trials per subject
    # ---------------------------------------------------------

    print()
    print("=" * 60)
    print("TRIALS PER SUBJECT")
    print("=" * 60)

    trials_per_subject = (
        dataframe.groupby(
            "subject_id"
        )
        .size()
    )

    print(
        trials_per_subject.describe()
        .round(2)
        .to_string()
    )

    # ---------------------------------------------------------
    # Final status
    # ---------------------------------------------------------

    has_missing = (
        not missing_features.empty
    )

    has_infinite = (
        bool(infinite_counts)
    )

    has_constant = (
        bool(constant_features)
    )

    has_duplicates = (
        duplicate_trial_ids > 0
    )

    has_leakage = (
        bool(leakage_candidates)
    )

    print()
    print("=" * 60)
    print("VALIDATION STATUS")
    print("=" * 60)

    print(
        f"Missing values:   "
        f"{'CHECK' if has_missing else 'OK'}"
    )

    print(
        f"Infinite values:  "
        f"{'CHECK' if has_infinite else 'OK'}"
    )

    print(
        f"Constant features:"
        f" {'CHECK' if has_constant else 'OK'}"
    )

    print(
        f"Duplicate trials: "
        f"{'CHECK' if has_duplicates else 'OK'}"
    )

    print(
        f"Target leakage:   "
        f"{'CHECK' if has_leakage else 'OK'}"
    )

    print()

    if not any(
        [
            has_missing,
            has_infinite,
            has_constant,
            has_duplicates,
            has_leakage,
        ]
    ):
        print(
            "Feature dataset passed "
            "basic validation."
        )
    else:
        print(
            "Feature dataset requires "
            "review before model training."
        )


if __name__ == "__main__":
    main()