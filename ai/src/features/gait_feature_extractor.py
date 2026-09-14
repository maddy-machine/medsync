import json
from pathlib import Path

import numpy as np
import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[2]

DATA_ROOT = (
    AI_ROOT
    / "data"
    / "extracted"
    / "dataset"
    / "data"
)

TRIAL_INDEX = (
    AI_ROOT
    / "data"
    / "processed"
    / "trial_index.csv"
)

OUTPUT_FILE = (
    AI_ROOT
    / "data"
    / "processed"
    / "oa_features.csv"
)


def safe_mean(values: np.ndarray) -> float:
    values = values[
        np.isfinite(values)
    ]

    if len(values) == 0:
        return 0.0

    return float(np.mean(values))


def safe_std(values: np.ndarray) -> float:
    values = values[
        np.isfinite(values)
    ]

    if len(values) < 2:
        return 0.0

    return float(np.std(values))


def safe_cv(values: np.ndarray) -> float:
    values = values[
        np.isfinite(values)
    ]

    if len(values) < 2:
        return 0.0

    mean = np.mean(values)

    if abs(mean) < 1e-12:
        return 0.0

    return float(
        np.std(values) / abs(mean)
    )


def magnitude(
    dataframe: pd.DataFrame,
    columns: list[str],
) -> np.ndarray:
    values = dataframe[
        columns
    ].to_numpy(dtype=float)

    valid_rows = np.all(
        np.isfinite(values),
        axis=1,
    )

    values = values[valid_rows]

    if len(values) == 0:
        return np.asarray(
            [],
            dtype=float,
        )

    return np.sqrt(
        np.sum(values * values, axis=1)
    )


def percentile_range(
    values: np.ndarray,
) -> float:
    values = values[
        np.isfinite(values)
    ]

    if len(values) == 0:
        return 0.0

    return float(
        np.percentile(values, 95)
        - np.percentile(values, 5)
    )


def extract_gait_timing_features(
    events: list,
    frequency: float,
    prefix: str,
) -> dict[str, float]:
    if len(events) < 2:
        return {
            f"{prefix}_event_count":
                float(len(events)),

            f"{prefix}_swing_duration_mean":
                0.0,

            f"{prefix}_swing_duration_std":
                0.0,

            f"{prefix}_swing_duration_cv":
                0.0,

            f"{prefix}_cycle_duration_mean":
                0.0,

            f"{prefix}_cycle_duration_std":
                0.0,

            f"{prefix}_cycle_duration_cv":
                0.0,

            f"{prefix}_stance_duration_mean":
                0.0,

            f"{prefix}_stance_duration_std":
                0.0,

            f"{prefix}_stance_duration_cv":
                0.0,
        }

    swing_durations = []
    cycle_durations = []
    stance_durations = []

    for index, event in enumerate(events):
        if len(event) < 2:
            continue

        toe_off = int(event[0])
        heel_strike = int(event[1])

        if heel_strike <= toe_off:
            continue

        swing_duration = (
            heel_strike - toe_off
        ) / frequency

        swing_durations.append(
            swing_duration
        )

        if index + 1 >= len(events):
            continue

        next_event = events[index + 1]

        if len(next_event) < 2:
            continue

        next_toe_off = int(
            next_event[0]
        )

        cycle_duration = (
            next_toe_off - toe_off
        ) / frequency

        stance_duration = (
            next_toe_off - heel_strike
        ) / frequency

        if cycle_duration > 0:
            cycle_durations.append(
                cycle_duration
            )

        if stance_duration > 0:
            stance_durations.append(
                stance_duration
            )

    return {
        f"{prefix}_event_count":
            float(len(events)),

        f"{prefix}_swing_duration_mean":
            safe_mean(
                np.asarray(
                    swing_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_swing_duration_std":
            safe_std(
                np.asarray(
                    swing_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_swing_duration_cv":
            safe_cv(
                np.asarray(
                    swing_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_cycle_duration_mean":
            safe_mean(
                np.asarray(
                    cycle_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_cycle_duration_std":
            safe_std(
                np.asarray(
                    cycle_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_cycle_duration_cv":
            safe_cv(
                np.asarray(
                    cycle_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_stance_duration_mean":
            safe_mean(
                np.asarray(
                    stance_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_stance_duration_std":
            safe_std(
                np.asarray(
                    stance_durations,
                    dtype=float,
                )
            ),

        f"{prefix}_stance_duration_cv":
            safe_cv(
                np.asarray(
                    stance_durations,
                    dtype=float,
                )
            ),
    }


def extract_asymmetry(
    left_value: float,
    right_value: float,
) -> float:
    if not (
        np.isfinite(left_value)
        and np.isfinite(right_value)
    ):
        return 0.0

    denominator = (
        abs(left_value)
        + abs(right_value)
    ) / 2.0

    if denominator < 1e-12:
        return 0.0

    return float(
        abs(left_value - right_value)
        / denominator
    )


def extract_trial_features(
    row: pd.Series,
) -> dict[str, float | int | str]:
    metadata_path = (
        AI_ROOT
        / row["metadata_file"]
    )

    processed_path = (
        AI_ROOT
        / row["processed_file"]
    )

    with metadata_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        metadata = json.load(file)

    frequency = float(
        metadata["freq"]
    )

    dataframe = pd.read_csv(
        processed_path,
        sep="\t",
    )

    required_columns = [
        "LF_FreeAcc_X",
        "LF_FreeAcc_Y",
        "LF_FreeAcc_Z",
        "LF_Gyr_X",
        "LF_Gyr_Y",
        "LF_Gyr_Z",
        "RF_FreeAcc_X",
        "RF_FreeAcc_Y",
        "RF_FreeAcc_Z",
        "RF_Gyr_X",
        "RF_Gyr_Y",
        "RF_Gyr_Z",
        "LB_FreeAcc_X",
        "LB_FreeAcc_Y",
        "LB_FreeAcc_Z",
        "LB_Gyr_X",
        "LB_Gyr_Y",
        "LB_Gyr_Z",
    ]

    missing_columns = [
        column
        for column in required_columns
        if column not in dataframe.columns
    ]

    if missing_columns:
        raise ValueError(
            "Required sensor columns are missing: "
            + ", ".join(missing_columns)
        )

    features: dict[
        str,
        float | int | str
    ] = {
        "subject_id":
            row["subject_id"],

        "trial_id":
            row["trial_id"],

        "oa_label":
            int(row["oa_label"]),

        "pathology_key":
            row["pathology_key"],

        "age":
            float(row["age"]),

        "bmi":
            float(row["bmi"]),

        "gender_male":
            1
            if str(row["gender"]).upper() == "M"
            else 0,

        "sampling_frequency_hz":
            frequency,
    }

    left_events = metadata.get(
        "leftGaitEvents",
        [],
    )

    right_events = metadata.get(
        "rightGaitEvents",
        [],
    )

    uturn = metadata.get(
        "uturnBoundaries",
        [],
    )

    left_timing = (
        extract_gait_timing_features(
            left_events,
            frequency,
            "left",
        )
    )

    right_timing = (
        extract_gait_timing_features(
            right_events,
            frequency,
            "right",
        )
    )

    features.update(left_timing)
    features.update(right_timing)

    features[
        "swing_duration_asymmetry"
    ] = extract_asymmetry(
        left_timing[
            "left_swing_duration_mean"
        ],
        right_timing[
            "right_swing_duration_mean"
        ],
    )

    features[
        "cycle_duration_asymmetry"
    ] = extract_asymmetry(
        left_timing[
            "left_cycle_duration_mean"
        ],
        right_timing[
            "right_cycle_duration_mean"
        ],
    )

    features[
        "stance_duration_asymmetry"
    ] = extract_asymmetry(
        left_timing[
            "left_stance_duration_mean"
        ],
        right_timing[
            "right_stance_duration_mean"
        ],
    )

    straight_segments = []

    if len(uturn) == 2:
        uturn_start = int(
            uturn[0]
        )

        uturn_end = int(
            uturn[1]
        )

        straight_segments.append(
            (0, uturn_start)
        )

        straight_segments.append(
            (
                uturn_end,
                len(dataframe),
            )
        )

    else:
        straight_segments.append(
            (0, len(dataframe))
        )

    left_acc_values = []
    right_acc_values = []

    left_gyro_values = []
    right_gyro_values = []

    lower_back_acc_values = []
    lower_back_gyro_values = []

    for start, end in straight_segments:
        start = max(
            0,
            start,
        )

        end = min(
            len(dataframe),
            end,
        )

        if end <= start:
            continue

        segment = dataframe.iloc[
            start:end
        ]

        left_acc_values.extend(
            magnitude(
                segment,
                [
                    "LF_FreeAcc_X",
                    "LF_FreeAcc_Y",
                    "LF_FreeAcc_Z",
                ],
            )
        )

        right_acc_values.extend(
            magnitude(
                segment,
                [
                    "RF_FreeAcc_X",
                    "RF_FreeAcc_Y",
                    "RF_FreeAcc_Z",
                ],
            )
        )

        left_gyro_values.extend(
            magnitude(
                segment,
                [
                    "LF_Gyr_X",
                    "LF_Gyr_Y",
                    "LF_Gyr_Z",
                ],
            )
        )

        right_gyro_values.extend(
            magnitude(
                segment,
                [
                    "RF_Gyr_X",
                    "RF_Gyr_Y",
                    "RF_Gyr_Z",
                ],
            )
        )

    lower_back_acc_values = magnitude(
        dataframe,
        [
            "LB_FreeAcc_X",
            "LB_FreeAcc_Y",
            "LB_FreeAcc_Z",
        ],
    )

    lower_back_gyro_values = magnitude(
        dataframe,
        [
            "LB_Gyr_X",
            "LB_Gyr_Y",
            "LB_Gyr_Z",
        ],
    )

    left_acc = np.asarray(
        left_acc_values,
        dtype=float,
    )

    right_acc = np.asarray(
        right_acc_values,
        dtype=float,
    )

    left_gyro = np.asarray(
        left_gyro_values,
        dtype=float,
    )

    right_gyro = np.asarray(
        right_gyro_values,
        dtype=float,
    )

    features.update(
        {
            "left_foot_acc_mean":
                safe_mean(left_acc),

            "left_foot_acc_std":
                safe_std(left_acc),

            "left_foot_acc_p95_range":
                percentile_range(left_acc),

            "right_foot_acc_mean":
                safe_mean(right_acc),

            "right_foot_acc_std":
                safe_std(right_acc),

            "right_foot_acc_p95_range":
                percentile_range(right_acc),

            "left_foot_gyro_mean":
                safe_mean(left_gyro),

            "left_foot_gyro_std":
                safe_std(left_gyro),

            "left_foot_gyro_p95_range":
                percentile_range(left_gyro),

            "right_foot_gyro_mean":
                safe_mean(right_gyro),

            "right_foot_gyro_std":
                safe_std(right_gyro),

            "right_foot_gyro_p95_range":
                percentile_range(right_gyro),
        }
    )

    features[
        "foot_acc_mean_asymmetry"
    ] = extract_asymmetry(
        features["left_foot_acc_mean"],
        features["right_foot_acc_mean"],
    )

    features[
        "foot_gyro_mean_asymmetry"
    ] = extract_asymmetry(
        features["left_foot_gyro_mean"],
        features["right_foot_gyro_mean"],
    )

    features.update(
        {
            "lower_back_acc_mean":
                safe_mean(
                    lower_back_acc_values
                ),

            "lower_back_acc_std":
                safe_std(
                    lower_back_acc_values
                ),

            "lower_back_acc_p95_range":
                percentile_range(
                    lower_back_acc_values
                ),

            "lower_back_gyro_mean":
                safe_mean(
                    lower_back_gyro_values
                ),

            "lower_back_gyro_std":
                safe_std(
                    lower_back_gyro_values
                ),

            "lower_back_gyro_p95_range":
                percentile_range(
                    lower_back_gyro_values
                ),
        }
    )

    features[
        "trial_duration_seconds"
    ] = len(dataframe) / frequency

    features[
        "uturn_duration_seconds"
    ] = (
        (
            int(uturn[1])
            - int(uturn[0])
        )
        / frequency
        if len(uturn) == 2
        else 0.0
    )

    return features


def main() -> None:
    print(
        "OA gait feature extraction"
    )
    print("=" * 60)

    if not TRIAL_INDEX.exists():
        raise FileNotFoundError(
            f"Trial index not found: "
            f"{TRIAL_INDEX}"
        )

    trial_index = pd.read_csv(
        TRIAL_INDEX
    )

    print(
        f"Trials to process: "
        f"{len(trial_index)}"
    )

    feature_rows = []
    failed_trials = []

    for index, row in trial_index.iterrows():
        try:
            features = extract_trial_features(
                row
            )

            feature_rows.append(
                features
            )

        except Exception as error:
            failed_trials.append(
                {
                    "trial_id":
                        row["trial_id"],
                    "error":
                        str(error),
                }
            )

        if (
            (index + 1) % 25 == 0
            or index + 1
            == len(trial_index)
        ):
            print(
                f"Processed "
                f"{index + 1}/"
                f"{len(trial_index)}"
            )

    if not feature_rows:
        raise RuntimeError(
            "No features were extracted."
        )

    feature_dataframe = pd.DataFrame(
        feature_rows
    )

    feature_dataframe = (
        feature_dataframe.sort_values(
            by=[
                "oa_label",
                "subject_id",
                "trial_id",
            ]
        )
        .reset_index(drop=True)
    )

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    feature_dataframe.to_csv(
        OUTPUT_FILE,
        index=False,
    )

    print()
    print("=" * 60)

    print(
        f"Feature rows created: "
        f"{len(feature_dataframe)}"
    )

    print(
        f"Feature columns: "
        f"{len(feature_dataframe.columns)}"
    )

    print()
    print("Class distribution:")

    print(
        feature_dataframe[
            "oa_label"
        ]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print()
    print(
        f"Failed trials: "
        f"{len(failed_trials)}"
    )

    if failed_trials:
        print()
        print("First failures:")

        for failure in failed_trials[:10]:
            print(
                f"  {failure['trial_id']}: "
                f"{failure['error']}"
            )

    print()
    print(
        "Saved feature dataset:"
    )

    print(
        f"  {OUTPUT_FILE}"
    )


if __name__ == "__main__":
    main()