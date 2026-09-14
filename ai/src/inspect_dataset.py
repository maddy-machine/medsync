import json
from pathlib import Path

import pandas as pd


DATA_ROOT = (
    Path(__file__).resolve().parents[1]
    / "data"
    / "extracted"
    / "dataset"
    / "data"
)


def find_first_metadata(cohort: str) -> Path:
    cohort_path = DATA_ROOT / cohort

    files = sorted(
        cohort_path.rglob("*_meta.json")
    )

    if not files:
        raise FileNotFoundError(
            f"No metadata files found for cohort: {cohort}"
        )

    return files[0]


def print_metadata(meta_path: Path) -> None:
    print("=" * 70)
    print("METADATA")
    print("=" * 70)
    print(f"File: {meta_path}")
    print()

    with meta_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        metadata = json.load(file)

    for key, value in metadata.items():
        if isinstance(value, list):
            print(
                f"{key}: "
                f"{type(value).__name__} "
                f"(length={len(value)})"
            )
        else:
            print(f"{key}: {value}")

    return metadata


def find_trial_files(meta_path: Path) -> list[Path]:
    trial_directory = meta_path.parent

    return sorted(
        trial_directory.iterdir()
    )


def inspect_trial(meta_path: Path) -> None:
    print()
    print("=" * 70)
    print("TRIAL FILES")
    print("=" * 70)

    files = find_trial_files(meta_path)

    for file in files:
        if file.is_file():
            print(
                f"{file.name:<45} "
                f"{file.stat().st_size:,} bytes"
            )

    print()

    txt_files = [
        file
        for file in files
        if file.suffix.lower() == ".txt"
    ]

    if not txt_files:
        print("No TXT sensor files found.")
        return

    print("=" * 70)
    print("SENSOR FILE INSPECTION")
    print("=" * 70)

    for txt_file in txt_files:
        print()
        print(f"FILE: {txt_file.name}")

        try:
            data = pd.read_csv(
                txt_file,
                sep="\t",
                nrows=5,
            )

            print(
                f"Rows inspected: {len(data)}"
            )

            print(
                f"Columns: {len(data.columns)}"
            )

            print(
                "Column names:"
            )

            for index, column in enumerate(
                data.columns,
                start=1,
            ):
                print(
                    f"  {index:2d}. {column}"
                )

            print()
            print("First rows:")

            print(
                data.to_string(
                    index=False
                )
            )

        except Exception as error:
            print(
                f"Could not read "
                f"{txt_file.name}: {error}"
            )


def inspect_cohort(cohort: str) -> None:
    print()
    print("#" * 70)
    print(f"COHORT: {cohort.upper()}")
    print("#" * 70)

    meta_path = find_first_metadata(
        cohort
    )

    print_metadata(meta_path)

    inspect_trial(meta_path)


def main() -> None:
    print("Clinical Gait Signals Dataset Inspector")
    print("=" * 70)
    print(f"Dataset root: {DATA_ROOT}")

    if not DATA_ROOT.exists():
        raise FileNotFoundError(
            f"Dataset root does not exist: "
            f"{DATA_ROOT}"
        )

    inspect_cohort("healthy")
    inspect_cohort("ortho")


if __name__ == "__main__":
    main()