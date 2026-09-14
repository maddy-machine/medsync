import zipfile
import csv
import io
import math

zip_path = r"ai\data\raw\dataset.zip"

REQUIRED_SENSORS = ["LF", "RF"]

def valid(value):
    try:
        return math.isfinite(float(value))
    except (ValueError, TypeError):
        return False

with zipfile.ZipFile(zip_path) as z:

    files = sorted(
        x for x in z.namelist()
        if "/ortho/KOA/" in x
        and x.endswith("_processed_data.txt")
    )

    print("KOA CONTIGUOUS VALID-SIGNAL ANALYSIS")
    print("Trials:", len(files))
    print()

    print(
        "Trial | Total rows | Valid rows | "
        "Valid % | Longest valid segment(s) | "
        "Segments"
    )
    print("-" * 115)

    for path in files:

        with z.open(path) as f:

            text = io.TextIOWrapper(
                f,
                encoding="utf-8",
                errors="replace"
            )

            reader = csv.DictReader(
                text,
                delimiter="\t"
            )

            total = 0
            valid_rows = 0

            current_segment = 0
            longest_segment = 0
            segment_count = 0

            for row in reader:

                total += 1

                row_valid = True

                for sensor in REQUIRED_SENSORS:

                    for axis in ["X", "Y", "Z"]:

                        for signal in ["FreeAcc", "Gyr"]:

                            column = (
                                f"{sensor}_{signal}_{axis}"
                            )

                            if not valid(row.get(column)):
                                row_valid = False
                                break

                        if not row_valid:
                            break

                    if not row_valid:
                        break

                if row_valid:

                    valid_rows += 1
                    current_segment += 1

                else:

                    if current_segment > 0:
                        segment_count += 1
                        longest_segment = max(
                            longest_segment,
                            current_segment
                        )

                    current_segment = 0

            if current_segment > 0:
                segment_count += 1
                longest_segment = max(
                    longest_segment,
                    current_segment
                )

        valid_percent = (
            100.0 * valid_rows / total
            if total
            else 0
        )

        longest_seconds = longest_segment / 100.0

        trial_name = path.split("/")[-1]

        print(
            trial_name,
            "|",
            total,
            "|",
            valid_rows,
            "|",
            f"{valid_percent:.2f}",
            "|",
            f"{longest_seconds:.2f}",
            "|",
            segment_count
        )

