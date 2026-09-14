import zipfile

zip_path = r"ai\data\raw\dataset.zip"

with zipfile.ZipFile(zip_path) as z:
    files = [
        x for x in z.namelist()
        if "/ortho/KOA/" in x
    ]

print("KOA FILE INVENTORY")
print("Total files:", len(files))
print()

for x in files[:200]:
    print(x)
