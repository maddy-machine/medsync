import random
from pathlib import Path

import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[1]

INPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_ml_dataset.csv"
)

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
GROUP_COLUMN = "subject_id"

RANDOM_STATE = 42
TEST_SIZE = 0.20


def create_subject_split(
    dataframe: pd.DataFrame,
) -> tuple[set[str], set[str]]:
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

    train_subjects: set[str] = set()
    test_subjects: set[str] = set()

    random_generator = random.Random(
        RANDOM_STATE
    )

    for label in sorted(
        subject_labels[TARGET_COLUMN]
        .unique()
    ):
        class_subjects = (
            subject_labels[
                subject_labels[
                    TARGET_COLUMN
                ]
                == label
            ][GROUP_COLUMN]
            .astype(str)
            .tolist()
        )

        random_generator.shuffle(
            class_subjects
        )

        test_count = max(
            1,
            round(
                len(class_subjects)
                * TEST_SIZE
            ),
        )

        class_test_subjects = set(
            class_subjects[
                :test_count
            ]
        )

        class_train_subjects = set(
            class_subjects[
                test_count:
            ]
        )

        test_subjects.update(
            class_test_subjects
        )

        train_subjects.update(
            class_train_subjects
        )

    return (
        train_subjects,
        test_subjects,
    )


def main() -> None:
    print(
        "Creating subject-level train/test split"
    )
    print("=" * 60)

    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"ML dataset not found:\n"
            f"{INPUT_FILE}"
        )

    dataframe = pd.read_csv(
        INPUT_FILE
    )

    print(
        f"Total trials: "
        f"{len(dataframe)}"
    )

    print(
        f"Total subjects: "
        f"{dataframe[GROUP_COLUMN].nunique()}"
    )

    print()

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

    print(
        "Subject class distribution:"
    )

    print(
        subject_labels[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()

    (
        train_subject_ids,
        test_subject_ids,
    ) = create_subject_split(
        dataframe
    )

    train_dataframe = dataframe[
        dataframe[
            GROUP_COLUMN
        ].astype(str).isin(
            train_subject_ids
        )
    ].copy()

    test_dataframe = dataframe[
        dataframe[
            GROUP_COLUMN
        ].astype(str).isin(
            test_subject_ids
        )
    ].copy()

    train_dataframe = (
        train_dataframe
        .sort_values(
            by=[
                TARGET_COLUMN,
                GROUP_COLUMN,
                "trial_id",
            ]
        )
        .reset_index(drop=True)
    )

    test_dataframe = (
        test_dataframe
        .sort_values(
            by=[
                TARGET_COLUMN,
                GROUP_COLUMN,
                "trial_id",
            ]
        )
        .reset_index(drop=True)
    )

    TRAIN_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    train_dataframe.to_csv(
        TRAIN_FILE,
        index=False,
    )

    test_dataframe.to_csv(
        TEST_FILE,
        index=False,
    )

    print(
        "=" * 60
    )

    print(
        "TRAINING SET"
    )

    print(
        f"Trials: "
        f"{len(train_dataframe)}"
    )

    print(
        f"Subjects: "
        f"{train_dataframe[GROUP_COLUMN].nunique()}"
    )

    print(
        "Class distribution:"
    )

    print(
        train_dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()

    print(
        "TEST SET"
    )

    print(
        f"Trials: "
        f"{len(test_dataframe)}"
    )

    print(
        f"Subjects: "
        f"{test_dataframe[GROUP_COLUMN].nunique()}"
    )

    print(
        "Class distribution:"
    )

    print(
        test_dataframe[
            TARGET_COLUMN
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()

    overlap = (
        train_subject_ids
        & test_subject_ids
    )

    print(
        "SUBJECT LEAKAGE CHECK"
    )

    print(
        f"Subjects in both sets: "
        f"{len(overlap)}"
    )

    if overlap:
        print(
            "ERROR: Subject leakage detected."
        )

        for subject in sorted(
            overlap
        ):
            print(
                f"  {subject}"
            )

        raise RuntimeError(
            "Train/test subject overlap detected."
        )

    print(
        "OK: No subject appears in "
        "both train and test sets."
    )

    print()

    print(
        "=" * 60
    )

    print(
        "Saved:"
    )

    print(
        f"  Train: {TRAIN_FILE}"
    )

    print(
        f"  Test:  {TEST_FILE}"
    )

    print()

    print(
        "Subject-level split complete."
    )


if __name__ == "__main__":
    main()