from pathlib import Path

import numpy as np
import pandas as pd
import sklearn


def main() -> None:
    root = Path(__file__).resolve().parents[1]

    directories = [
        root / "data" / "raw",
        root / "data" / "processed",
        root / "models",
        root / "reports",
        root / "src" / "features",
        root / "src" / "models",
        root / "src" / "evaluation",
        root / "notebooks",
    ]

    print("OA AI workspace")
    print("=" * 40)

    print("Python packages:")
    print(f"  NumPy:        {np.__version__}")
    print(f"  Pandas:       {pd.__version__}")
    print(f"  scikit-learn: {sklearn.__version__}")

    print()
    print("Workspace directories:")

    all_present = True

    for directory in directories:
        exists = directory.exists()

        status = "OK" if exists else "MISSING"

        print(
            f"  [{status}] "
            f"{directory.relative_to(root)}"
        )

        if not exists:
            all_present = False

    print()

    if all_present:
        print("AI workspace is ready.")
    else:
        print(
            "Some workspace directories are missing."
        )


if __name__ == "__main__":
    main()