import zipfile
import csv
import io
import math
import statistics

zip_path = r"ai\data\raw\dataset.zip"

SENSORS = ["HE", "LB", "LF", "RF"]

def is_number(value):
    try:
        x = float(value)
        return math.isfinite(x)
    except (ValueError, TypeError):
        return False

with zipfile.ZipFile(zip_path) as z:

    files = sorted(
        x for x in z.namelist()
        if "/ortho/KOA/" in x
        and x.endswith("_processed_data.txt")
    )

    print("KOA SIGNAL QUALITY SUMMARY")
    print("Processed trials:", len(files))
    print()

    all_durations = []
    all_intervals = []

    print(
        "Trial | Samples | Duration(s) | "
        "Mean dt(ms) | Invalid | "
        "FreeAcc max | Gyro max"
    )
    print("-" * 110)

    for path in files:

        with z.open(path) as f:
            text = io.TextIOWrapper(
                f,
                encoding="utf-8",
                errors="replace"
            )

            reader = csv.DictReader(text, delimiter="\t")

            rows = list(reader)

        sample_count = len(rows)

        packet_values = []
        invalid_count = 0
        free_acc_values = []
        gyro_values = []

        for row in rows:

            packet = row.get("PacketCounter")

            if is_number(packet):
                packet_values.append(float(packet))
            else:
                invalid_count += 1

            for sensor in SENSORS:

                for axis in ["X", "Y", "Z"]:

                    free_col = f"{sensor}_FreeAcc_{axis}"
                    gyro_col = f"{sensor}_Gyr_{axis}"

                    free_value = row.get(free_col)
                    gyro_value = row.get(gyro_col)

                    if is_number(free_value):
                        free_acc_values.append(
                            abs(float(free_value))
                        )
                    else:
                        invalid_count += 1

                    if is_number(gyro_value):
                        gyro_values.append(
                            abs(float(gyro_value))
                        )
                    else:
                        invalid_count += 1

        if len(packet_values) >= 2:

            duration = (
                packet_values[-1]
                - packet_values[0]
            ) / 100.0

            intervals = [
                packet_values[i + 1]
                - packet_values[i]
                for i in range(len(packet_values) - 1)
            ]

            mean_interval = (
                statistics.mean(intervals)
                if intervals
                else 0
            )

        else:
            duration = 0
            mean_interval = 0

        all_durations.append(duration)
        all_intervals.append(mean_interval)

        free_max = (
            max(free_acc_values)
            if free_acc_values
            else 0
        )

        gyro_max = (
            max(gyro_values)
            if gyro_values
            else 0
        )

        trial_name = path.split("/")[-1]

        print(
            trial_name,
            "|",
            sample_count,
            "|",
            f"{duration:.2f}",
            "|",
            f"{mean_interval * 10:.2f}",
            "|",
            invalid_count,
            "|",
            f"{free_max:.4f}",
            "|",
            f"{gyro_max:.4f}"
        )

    print()
    print("OVERALL SUMMARY")
    print("----------------")

    print(
        "Duration range:",
        f"{min(all_durations):.2f}",
        "to",
        f"{max(all_durations):.2f}",
        "seconds"
    )

    print(
        "Mean duration:",
        f"{statistics.mean(all_durations):.2f}",
        "seconds"
    )

    print(
        "Mean packet interval:",
        f"{statistics.mean(all_intervals):.4f}",
        "samples"
    )

