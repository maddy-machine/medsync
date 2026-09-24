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
        root / "artifacts",
        root / "src" / "features",
        root / "src" / "models",
        root / "src" / "evaluation",
        root / "notebooks",
    ]

    print("=" * 60)
    print("MedSync Multimodal AI Workspace & Environment Verification")
    print("=" * 60)

    print("\nCore Python Packages:")
    print(f"  NumPy:        {np.__version__}")
    print(f"  Pandas:       {pd.__version__}")
    print(f"  scikit-learn: {sklearn.__version__}")

    # Check Multimodal Fusion modules
    print("\nMultimodal Fusion Modules:")
    try:
        from src.models.patch_tst_encoder import PatchTSTEncoder, PatchTSTConfig
        tst = PatchTSTEncoder(PatchTSTConfig())
        print("  [OK] PatchTST Transformer Encoder (src.models.patch_tst_encoder)")
    except Exception as e:
        print(f"  [ERROR] PatchTST Transformer: {e}")

    try:
        from src.models.train_fusion_model import CrossModalAttentionFusion, FusionModelConfig
        fusion = CrossModalAttentionFusion(FusionModelConfig())
        print("  [OK] Cross-Modal Attention Fusion (src.models.train_fusion_model)")
    except Exception as e:
        print(f"  [ERROR] Fusion Model: {e}")

    print("\nWorkspace Directories:")
    all_present = True

    for directory in directories:
        # Create directories if they don't exist to ensure workspace readiness
        if not directory.exists():
            try:
                directory.mkdir(parents=True, exist_ok=True)
            except Exception:
                pass
        
        exists = directory.exists()
        status = "OK" if exists else "MISSING"

        print(f"  [{status}] {directory.relative_to(root)}")
        if not exists:
            all_present = False

    print()
    if all_present:
        print("AI Multimodal Fusion workspace is fully configured and ready.")
    else:
        print("Some workspace directories are missing.")


if __name__ == "__main__":
    main()