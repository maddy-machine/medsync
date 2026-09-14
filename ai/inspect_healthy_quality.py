import zipfile
import csv
import json
import statistics
import collections

zip_path = r"ai\data\raw\dataset.zip"

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
]

with zipfile.ZipFile(zip_path) as z:

    files = [
        x for x in z.namelist()
        if "/healthy/" in x
        and x.endswith("_processed_data.txt")
    ]

    print("HEALTHY SIGNAL QUALITY")
    print("-" * 100)
    print("Total processed trials:", len(files))
    print()

    durations = []
    valid_percentages = []
    invalid_trials = []
    bad_structure = []
    sampling_values = collections.Counter()

    for path in files:

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

            freq = float(meta.get("freq", 0))
            sampling_values[freq] += 1

            raw = z.read(path).decode(
                "utf-8",
                errors="replace"
            )

            lines = raw.splitlines()

            if not lines:
                bad_structure.append(path)
                continue

            reader = csv.DictReader(
                lines,
                delimiter="\t"
            )

            headers = reader.fieldnames or []

            missing = [
                c for c in required_columns
                if c not in headers
            ]

            if missing:
                bad_structure.append(
                    (path, missing)
                )
                continue

            rows = list(reader)

            total = len(rows)
            valid_rows = []

            for row in rows:

                packet = row.get("PacketCounter", "").strip()

                if not packet:
                    continue

                try:
                    int(float(packet))
                except ValueError:
                    continue

                good = True

                for c in required_columns:
                    value = row.get(c, "").strip()

                    if not value:
                        good = False
                        break

                    try:
                        float(value)
                    except ValueError:
                        good = False
                        break

                if good:
                    valid_rows.append(row)

            valid = len(valid_rows)

            if valid > 0:
                duration = valid / freq
                durations.append(duration)

            percentage = (
                valid / total * 100
                if total > 0
                else 0
            )

            valid_percentages.append(percentage)

            if percentage < 99.0:
                invalid_trials.append(
                    (
                        path,
                        total,
                        valid,
                        percentage
                    )
                )

        except Exception as e:
            bad_structure.append(
                (path, str(e))
            )

    print("Sampling frequencies:")
    for freq, count in sorted(sampling_values.items()):
        print(f"  {freq} Hz: {count} trials")

    print()

    if durations:
        print(
            "Duration seconds:",
            "min =", round(min(durations), 2),
            "max =", round(max(durations), 2),
            "mean =", round(statistics.mean(durations), 2)
        )

    print()

    if valid_percentages:
        print(
            "Valid-row percentage:",
            "min =", round(min(valid_percentages), 2),
            "max =", round(max(valid_percentages), 2),
            "mean =", round(statistics.mean(valid_percentages), 2)
        )

    print()

    print(
        "Trials below 99% valid:",
        len(invalid_trials)
    )

    for item in invalid_trials[:20]:
        print(
            " ",
            item[0],
            "| total =", item[1],
            "| valid =", item[2],
            "| valid % =", round(item[3], 2)
        )

    print()

    print(
        "Trials with structural problems:",
        len(bad_structure)
    )

    for item in bad_structure[:20]:
        print(" ", item)

