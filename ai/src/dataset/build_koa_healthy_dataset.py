import csv
import json
import math
import os
import statistics
import zipfile


ZIP_PATH = r"ai\data\raw\dataset.zip"
OUTPUT_PATH = r"ai\data\processed\koa_vs_healthy_features.csv"

SAMPLE_RATE = 100.0


def safe_float(value):
    try:
        value = float(value)
        if math.isfinite(value):
            return value
    except (TypeError, ValueError):
        pass

    return None


def magnitude(x, y, z):
    return math.sqrt(
        x * x +
        y * y +
        z * z
    )


def mean(values):
    return statistics.fmean(values) if values else 0.0


def std(values):
    if len(values) < 2:
        return 0.0

    return statistics.stdev(values)


def coefficient_of_variation(values):
    if len(values) < 2:
        return 0.0

    m = mean(values)

    if abs(m) < 1e-12:
        return 0.0

    return std(values) / abs(m)


def percentile(values, p):
    if not values:
        return 0.0

    ordered = sorted(values)

    if len(ordered) == 1:
        return ordered[0]

    position = (len(ordered) - 1) * p
    lower = int(math.floor(position))
    upper = int(math.ceil(position))

    if lower == upper:
        return ordered[lower]

    fraction = position - lower

    return (
        ordered[lower] +
        fraction *
        (ordered[upper] - ordered[lower])
    )


def largest_contiguous_segment(rows):
    if not rows:
        return []

    segments = []
    current = []

    previous_packet = None

    for row in rows:

        packet = safe_float(
            row.get("PacketCounter")
        )

        if packet is None:
            if current:
                segments.append(current)

            current = []
            previous_packet = None
            continue

        packet = int(packet)

        if (
            previous_packet is not None
            and packet != previous_packet + 1
        ):
            if current:
                segments.append(current)

            current = []

        current.append(row)
        previous_packet = packet

    if current:
        segments.append(current)

    if not segments:
        return []

    return max(
        segments,
        key=len
    )


def extract_vector(rows, prefix):
    acc = []
    gyr = []

    for row in rows:

        ax = safe_float(
            row.get(f"{prefix}_FreeAcc_X")
        )
        ay = safe_float(
            row.get(f"{prefix}_FreeAcc_Y")
        )
        az = safe_float(
            row.get(f"{prefix}_FreeAcc_Z")
        )

        gx = safe_float(
            row.get(f"{prefix}_Gyr_X")
        )
        gy = safe_float(
            row.get(f"{prefix}_Gyr_Y")
        )
        gz = safe_float(
            row.get(f"{prefix}_Gyr_Z")
        )

        if None in (
            ax, ay, az,
            gx, gy, gz
        ):
            continue

        acc.append(
            magnitude(
                ax, ay, az
            )
        )

        gyr.append(
            magnitude(
                gx, gy, gz
            )
        )

    return acc, gyr


def extract_features(rows, meta, label, subject, trial):

    lf_acc, lf_gyr = extract_vector(
        rows,
        "LF"
    )

    rf_acc, rf_gyr = extract_vector(
        rows,
        "RF"
    )

    if not lf_acc or not rf_acc:
        return None

    all_acc = lf_acc + rf_acc
    all_gyr = lf_gyr + rf_gyr

    min_length = min(
        len(lf_acc),
        len(rf_acc)
    )

    if min_length < 100:
        return None

    lf_acc = lf_acc[:min_length]
    rf_acc = rf_acc[:min_length]

    lf_gyr = lf_gyr[:min_length]
    rf_gyr = rf_gyr[:min_length]

    bilateral_acc_diff = [
        abs(l - r)
        for l, r in zip(
            lf_acc,
            rf_acc
        )
    ]

    bilateral_gyr_diff = [
        abs(l - r)
        for l, r in zip(
            lf_gyr,
            rf_gyr
        )
    ]

    duration = min_length / SAMPLE_RATE

    age = safe_float(
        meta.get("age")
    )

    bmi = safe_float(
        meta.get("BMI")
    )

    features = {

        "subject_id": subject,
        "trial_id": trial,
        "oa_label": label,

        "age": (
            age
            if age is not None
            else 0.0
        ),

        "bmi": (
            bmi
            if bmi is not None
            else 0.0
        ),

        "duration_seconds": duration,

        "lf_acc_mean": mean(lf_acc),
        "lf_acc_std": std(lf_acc),
        "lf_acc_p95": percentile(
            lf_acc,
            0.95
        ),

        "rf_acc_mean": mean(rf_acc),
        "rf_acc_std": std(rf_acc),
        "rf_acc_p95": percentile(
            rf_acc,
            0.95
        ),

        "lf_gyr_mean": mean(lf_gyr),
        "lf_gyr_std": std(lf_gyr),
        "lf_gyr_p95": percentile(
            lf_gyr,
            0.95
        ),

        "rf_gyr_mean": mean(rf_gyr),
        "rf_gyr_std": std(rf_gyr),
        "rf_gyr_p95": percentile(
            rf_gyr,
            0.95
        ),

        "bilateral_acc_diff_mean":
            mean(
                bilateral_acc_diff
            ),

        "bilateral_acc_diff_std":
            std(
                bilateral_acc_diff
            ),

        "bilateral_gyr_diff_mean":
            mean(
                bilateral_gyr_diff
            ),

        "bilateral_gyr_diff_std":
            std(
                bilateral_gyr_diff
            ),

        "acc_mean":
            mean(all_acc),

        "acc_std":
            std(all_acc),

        "acc_cv":
            coefficient_of_variation(
                all_acc
            ),

        "gyr_mean":
            mean(all_gyr),

        "gyr_std":
            std(all_gyr),

        "gyr_cv":
            coefficient_of_variation(
                all_gyr
            ),

        "lf_rf_acc_ratio":
            (
                mean(lf_acc) /
                max(mean(rf_acc), 1e-12)
            ),

        "lf_rf_gyr_ratio":
            (
                mean(lf_gyr) /
                max(mean(rf_gyr), 1e-12)
            ),
    }

    return features


def process_cohort(
    z,
    cohort,
    label
):

    results = []

    prefix = (
        "dataset/data/"
        f"{cohort}/"
    )

    paths = [
        path
        for path in z.namelist()
        if path.startswith(prefix)
        and path.endswith(
            "_processed_data.txt"
        )
    ]

    print(
        f"{cohort}: {len(paths)} trials"
    )

    for index, path in enumerate(paths, 1):

        try:

            meta_path = path.replace(
                "_processed_data.txt",
                "_meta.json"
            )

            meta = json.loads(
                z.read(meta_path).decode(
                    "utf-8",
                    errors="replace"
                )
            )

            raw = z.read(path).decode(
                "utf-8",
                errors="replace"
            )

            reader = csv.DictReader(
                raw.splitlines(),
                delimiter="\t"
            )

            rows = list(reader)

            clean_rows = []

            for row in rows:

                packet = safe_float(
                    row.get(
                        "PacketCounter"
                    )
                )

                if packet is None:
                    continue

                required = [
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
                ]

                valid = True

                for column in required:

                    if (
                        safe_float(
                            row.get(column)
                        )
                        is None
                    ):
                        valid = False
                        break

                if valid:
                    clean_rows.append(row)

            rows = largest_contiguous_segment(
                clean_rows
            )

            if len(rows) < 100:
                continue

            subject = str(
                meta.get(
                    "subject",
                    "UNKNOWN"
                )
            )

            trial = os.path.basename(
                path
            ).replace(
                "_processed_data.txt",
                ""
            )

            features = extract_features(
                rows,
                meta,
                label,
                subject,
                trial
            )

            if features is not None:
                results.append(features)

        except Exception as error:

            print(
                "Skipped:",
                path,
                "|",
                error
            )

        if index % 50 == 0:
            print(
                f"  processed {index}/{len(paths)}"
            )

    return results


def main():

    os.makedirs(
        os.path.dirname(
            OUTPUT_PATH
        ),
        exist_ok=True
    )

    with zipfile.ZipFile(
        ZIP_PATH
    ) as z:

        healthy = process_cohort(
            z,
            "healthy/HS",
            0
        )

        koa = process_cohort(
            z,
            "ortho/KOA",
            1
        )

    rows = healthy + koa

    if not rows:
        raise RuntimeError(
            "No usable trials were extracted."
        )

    feature_names = [
        key
        for key in rows[0].keys()
        if key not in (
            "subject_id",
            "trial_id",
            "oa_label"
        )
    ]

    fieldnames = [
        "subject_id",
        "trial_id",
        "oa_label"
    ] + feature_names

    with open(
        OUTPUT_PATH,
        "w",
        newline="",
        encoding="utf-8"
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=fieldnames
        )

        writer.writeheader()
        writer.writerows(rows)

    subjects = {
        row["subject_id"]
        for row in rows
    }

    healthy_trials = sum(
        row["oa_label"] == 0
        for row in rows
    )

    koa_trials = sum(
        row["oa_label"] == 1
        for row in rows
    )

    healthy_subjects = {
        row["subject_id"]
        for row in rows
        if row["oa_label"] == 0
    }

    koa_subjects = {
        row["subject_id"]
        for row in rows
        if row["oa_label"] == 1
    }

    print()
    print("=" * 70)
    print("DATASET CREATED")
    print("=" * 70)

    print(
        "Output:",
        OUTPUT_PATH
    )

    print(
        "Rows:",
        len(rows)
    )

    print(
        "Features:",
        len(feature_names)
    )

    print()

    print(
        "Healthy trials:",
        healthy_trials
    )

    print(
        "Healthy subjects:",
        len(healthy_subjects)
    )

    print(
        "KOA trials:",
        koa_trials
    )

    print(
        "KOA subjects:",
        len(koa_subjects)
    )

    print(
        "Total subjects:",
        len(subjects)
    )

    print()

    print(
        "Feature columns:"
    )

    for name in feature_names:
        print(
            " ",
            name
        )


if __name__ == "__main__":
    main()
