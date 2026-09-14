import zipfile
import csv
import io
import collections

zip_path = r"ai\data\raw\dataset.zip"

with zipfile.ZipFile(zip_path) as z:
    files = [
        x for x in z.namelist()
        if "/ortho/KOA/" in x
        and x.endswith("_processed_data.txt")
    ]

    print("KOA PROCESSED SIGNAL STRUCTURE")
    print("Processed files found:", len(files))
    print()

    headers = collections.Counter()
    column_examples = {}

    for x in files:
        with z.open(x) as f:
            text = io.TextIOWrapper(
                f,
                encoding="utf-8",
                errors="replace"
            )

            reader = csv.reader(text, delimiter="\t")
            header = next(reader)

            headers[tuple(header)] += 1

            for col in header:
                column_examples.setdefault(col, [])

            for row in reader:
                for i, value in enumerate(row):
                    if i >= len(header):
                        continue

                    col = header[i]

                    if len(column_examples[col]) < 5:
                        try:
                            column_examples[col].append(float(value))
                        except ValueError:
                            pass

    print("UNIQUE HEADER STRUCTURES:", len(headers))
    print()

    for i, (header, count) in enumerate(headers.items(), 1):
        print("HEADER STRUCTURE", i)
        print("Files:", count)
        print("Columns:", len(header))
        print(" | ".join(header))
        print()

    print("COLUMN SAMPLE VALUES")
    print("--------------------")

    for col in sorted(column_examples):
        print(col, ":", column_examples[col])
