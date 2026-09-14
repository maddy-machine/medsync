import zipfile
import json
import collections

zip_path = r"ai\data\raw\dataset.zip"

with zipfile.ZipFile(zip_path) as z:

    files = [
        x for x in z.namelist()
        if "/healthy/" in x
        and x.endswith("_meta.json")
    ]

    subjects = collections.defaultdict(list)

    for x in files:

        data = json.loads(
            z.read(x).decode(
                "utf-8",
                errors="replace"
            )
        )

        subjects[str(data["subject"])].append(data)

print("HEALTHY SUBJECT SUMMARY")
print(
    "Subject | Trials | Age | Sex | BMI | "
    "Laterality | Freq | Protocol"
)
print("-" * 120)

for subject, trials in sorted(subjects.items()):

    d = trials[0]

    print(
        subject, "|",
        len(trials), "|",
        d.get("age"), "|",
        d.get("gender"), "|",
        d.get("BMI"), "|",
        d.get("laterality"), "|",
        d.get("freq"), "|",
        d.get("protocol")
    )

print()
print("Unique healthy subjects:", len(subjects))
print("Total healthy trials:", len(files))
