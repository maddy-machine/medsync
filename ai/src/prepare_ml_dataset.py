from pathlib import Path

import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[1]

INPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_features.csv"
)

OUTPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_ml_dataset.csv"
)


TARGET_COLUMN = "oa_label"


IDENTIFIER_COLUMNS = [
    "subject_id",
    "trial_id",
    "pathology_key",
]


CONSTANT_COLUMNS = [
    "sampling_frequency_hz",
]


def main() -> None:
    print(
        "Preparing ML dataset"
    )
    print("=" * 60)

    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Feature dataset not found:\n"
            f"{INPUT_FILE}"
        )

    dataframe = pd.read_csv(
        INPUT_FILE
    )

    print(
        f"Input rows: "
        f"{len(dataframe)}"
    )

    print(
        f"Input columns: "
        f"{len(dataframe.columns)}"
    )

    print()
    print("Removing constant columns:")

    removed_columns = []

    for column in CONSTANT_COLUMNS:
        if column in dataframe.columns:
            dataframe = dataframe.drop(
                columns=[column]
            )

            removed_columns.append(
                column
            )

            print(
                f"  - {column}"
            )

    if not removed_columns:
        print(
            "  None"
        )

    feature_columns = [
        column
        for column in dataframe.columns
        if column not in IDENTIFIER_COLUMNS
        and column != TARGET_COLUMN
    ]

    print()
    print(
        f"ML feature count: "
        f"{len(feature_columns)}"
    )

    print()
    print("ML features:")

    for index, column in enumerate(
        feature_columns,
        start=1,
    ):
        print(
            f"  {index:2d}. {column}"
        )

    print()
    print("Target distribution:")

    print(
        dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()
    print("Saving ML dataset:")

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    dataframe.to_csv(
        OUTPUT_FILE,
        index=False,
    )

    print(
        f"  {OUTPUT_FILE}"
    )

    print()
    print("=" * 60)
    print("ML DATASET PREPARATION COMPLETE")
    print("=" * 60)

    print(
        f"Rows: "
        f"{len(dataframe)}"
    )

    print(
        f"Columns: "
        f"{len(dataframe.columns)}"
    )

    print(
        f"Features: "
        f"{len(feature_columns)}"
    )

    print(
        "Identifiers retained: "
        f"{len(IDENTIFIER_COLUMNS)}"
    )

    print(
        f"Target: "
        f"{TARGET_COLUMN}"
    )


if __name__ == "__main__":
    main()