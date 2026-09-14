import zipfile
import csv
import io
import math
import collections

zip_path = r"ai\data\raw\dataset.zip"

TARGETS = [
    "KOA_17_3",
    "KOA_17_4",
]

SENSORS = ["HE", "LB", "LF", "RF"]

with zipfile.ZipFile(zip_path) as z:

    files = [
        x for x in z.namelist()
        if "/ortho/KOA/" in x
        and x.endswith("_processed_data.txt")
    ]

    for target in TARGETS:

        path = next(
            x for x in files
            if target in x
        )

        print("=" * 100)
        print("TRIAL:", target)
        print("FILE:", path)
        print("=" * 100)

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

            invalid_by_column = collections.Counter()
            invalid_examples = collections.defaultdict(list)

            total_rows = 0

            for row_number, row in enumerate(reader, start=2):

                total_rows += 1

                for column, value in row.items():

                    try:
                        number = float(value)

                        if not math.isfinite(number):
                            invalid_by_column[column] += 1

                            if len(invalid_examples[column]) < 5:
                                invalid_examples[column].append(
                                    repr(value)
                                )

                    except (ValueError, TypeError):

                        invalid_by_column[column] += 1

                        if len(invalid_examples[column]) < 5:
                            invalid_examples[column].append(
                                repr(value)
                            )

            print("Total rows:", total_rows)
            print()

            print("INVALID VALUES BY COLUMN")
            print("------------------------")

            if not invalid_by_column:
                print("NONE")
            else:
                for column, count in invalid_by_column.most_common():
                    print(
                        column,
                        "| count =", count,
                        "| examples =", invalid_examples[column]
                    )

            print()

            # Also inspect whether PacketCounter remains continuous.
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

                packets = []

                for row in reader:
                    try:
                        packets.append(
                            int(float(row["PacketCounter"]))
                        )
                    except:
                        pass

            gaps = []

            for i in range(len(packets) - 1):

                difference = packets[i + 1] - packets[i]

                if difference != 1:
                    gaps.append(
                        (
                            packets[i],
                            packets[i + 1],
                            difference
                        )
                    )

            print("PACKET COUNTER CHECK")
            print("--------------------")
            print("Valid packet values:", len(packets))
            print("Packet gaps:", len(gaps))

            if gaps:
                print("First 10 gaps:")
                for gap in gaps[:10]:
                    print(gap)
            else:
                print("No packet gaps detected.")

            print()

