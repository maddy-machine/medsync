import json
from pathlib import Path

import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[1]

DATA_ROOT = (
    AI_ROOT
    / "data"
    / "extracted"
    / "dataset"
    / "data"
)

OUTPUT_DIR = (
    AI_ROOT
    / "data"
    / "processed"
)

OUTPUT_FILE = (
    OUTPUT_DIR
    / "trial_index.csv"
)


def load_metadata(
    metadata_path: Path,
) -> dict:
    with metadata_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        return json.load(file)


def determine_label(
    pathology_key: str | None,
) -> int | None:
    if pathology_key == "KOA":
        return 1

    if pathology_key == "HS":
        return 0

    return None


def build_index() -> pd.DataFrame:
    records = []

    metadata_files = sorted(
        DATA_ROOT.rglob("*_meta.json")
    )

    print(
        f"Metadata files found: "
        f"{len(metadata_files)}"
    )

    for metadata_path in metadata_files:
        metadata = load_metadata(
            metadata_path
        )

        pathology_key = metadata.get(
            "pathologyKey"
        )

        label = determine_label(
            pathology_key
        )

        # Only include the two classes
        # required for the first OA model:
        #
        #   HS  = healthy
        #   KOA = knee osteoarthritis
        #
        # ACL, HOA, and neuro are excluded.
        if label is None:
            continue

        trial_directory = (
            metadata_path.parent
        )

        processed_file = (
            trial_directory
            / (
                metadata_path.stem.replace(
                    "_meta",
                    "_processed_data",
                )
                + ".txt"
            )
        )

        records.append(
            {
                "subject_id":
                    metadata.get(
                        "subject"
                    ),

                "trial_id":
                    f"{metadata.get('subject')}_"
                    f"{metadata.get('trial')}",

                "cohort":
                    metadata.get(
                        "group"
                    ),

                "pathology":
                    metadata.get(
                        "pathology"
                    ),

                "pathology_key":
                    pathology_key,

                "oa_label":
                    label,

                "age":
                    metadata.get(
                        "age"
                    ),

                "gender":
                    metadata.get(
                        "gender"
                    ),

                "height_m":
                    metadata.get(
                        "height"
                    ),

                "weight_kg":
                    metadata.get(
                        "weight"
                    ),

                "bmi":
                    metadata.get(
                        "BMI"
                    ),

                "laterality":
                    metadata.get(
                        "laterality"
                    ),

                "clinical_deficit_side":
                    metadata.get(
                        "clinicalDeficitSide"
                    ),

                "evaluation_score_name":
                    metadata.get(
                        "evaluationScoreName"
                    ),

                "evaluation_score":
                    metadata.get(
                        "evaluationScoreValue"
                    ),

                "session":
                    metadata.get(
                        "session"
                    ),

                "days_since_first_session":
                    metadata.get(
                        "daysSinceFirstSession"
                    ),

                "trial":
                    metadata.get(
                        "trial"
                    ),

                "sampling_frequency_hz":
                    metadata.get(
                        "freq"
                    ),

                "sensor":
                    metadata.get(
                        "sensor"
                    ),

                "protocol":
                    metadata.get(
                        "protocol"
                    ),

                "visual_gait_assessment":
                    metadata.get(
                        "visualGaitAssessment"
                    ),

                "processed_file":
                    str(
                        processed_file
                        .relative_to(AI_ROOT)
                    ),

                "metadata_file":
                    str(
                        metadata_path
                        .relative_to(AI_ROOT)
                    ),

                "has_processed_file":
                    processed_file.exists(),

                "left_gait_event_count":
                    len(
                        metadata.get(
                            "leftGaitEvents",
                            []
                        )
                    ),

                "right_gait_event_count":
                    len(
                        metadata.get(
                            "rightGaitEvents",
                            []
                        )
                    ),
            }
        )

    return pd.DataFrame(records)


def main() -> None:
    print(
        "Building OA trial index"
    )
    print("=" * 60)

    if not DATA_ROOT.exists():
        raise FileNotFoundError(
            f"Dataset directory not found: "
            f"{DATA_ROOT}"
        )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    dataframe = build_index()

    if dataframe.empty:
        raise RuntimeError(
            "No healthy or KOA trials "
            "were found."
        )

    dataframe = dataframe.sort_values(
        by=[
            "oa_label",
            "subject_id",
            "session",
            "trial",
        ]
    ).reset_index(
        drop=True
    )

    dataframe.to_csv(
        OUTPUT_FILE,
        index=False,
    )

    print()
    print(
        f"Indexed trials: "
        f"{len(dataframe)}"
    )

    print()
    print("Class distribution:")

    class_counts = (
        dataframe["pathology_key"]
        .value_counts()
    )

    for class_name, count in (
        class_counts.items()
    ):
        print(
            f"  {class_name}: {count}"
        )

    print()
    print(
        "Unique subjects:"
    )

    subject_counts = (
        dataframe.groupby(
            "pathology_key"
        )["subject_id"]
        .nunique()
    )

    for class_name, count in (
        subject_counts.items()
    ):
        print(
            f"  {class_name}: {count}"
        )

    print()
    print(
        "Processed sensor files:"
    )

    processed_count = int(
        dataframe[
            "has_processed_file"
        ].sum()
    )

    print(
        f"  {processed_count} / "
        f"{len(dataframe)}"
    )

    print()
    print(
        f"Saved to:"
    )

    print(
        f"  {OUTPUT_FILE}"
    )


if __name__ == "__main__":
    main()