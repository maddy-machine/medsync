"""
Multimodal Sensor-Vision Fusion Training and Export Pipeline.

Fuses:
1. YOLOv8-Pose Vision Features (17 COCO Keypoints + geometric biomechanical angles)
2. PatchTST IMU Embeddings (Wearable motion transformer representations)

Outputs:
- Exportable Cross-Modal Attention Weights and Fusion configuration for on-device execution.
"""

from dataclasses import asdict, dataclass
import json
from pathlib import Path
from typing import Any, Dict, List, Tuple
import numpy as np

from .patch_tst_encoder import PatchTSTConfig, PatchTSTEncoder, softmax


@dataclass
class FusionModelConfig:
    vision_feature_dim: int = 12       # Valgus, trunk shift, flexion, confidence + key joint coords
    sensor_embedding_dim: int = 64     # PatchTST d_model
    hidden_dim: int = 32
    fusion_method: str = "cross_attention_weighted_v1"
    version: str = "1.0.0"
    random_seed: int = 42


class CrossModalAttentionFusion:
    """
    Cross-modal Attention Fusion layer.
    Allows vision tokens to attend to sensor embeddings and vice-versa,
    producing a unified representation that predicts knee OA / fall risk.
    """

    def __init__(self, config: FusionModelConfig):
        self.config = config
        rng = np.random.RandomState(config.random_seed)

        v_dim = config.vision_feature_dim
        s_dim = config.sensor_embedding_dim
        h_dim = config.hidden_dim

        # Project both modalities to common hidden space
        limit_v = np.sqrt(6.0 / (v_dim + h_dim))
        limit_s = np.sqrt(6.0 / (s_dim + h_dim))
        
        self.w_v_proj = rng.uniform(-limit_v, limit_v, (v_dim, h_dim))
        self.b_v_proj = np.zeros(h_dim)

        self.w_s_proj = rng.uniform(-limit_s, limit_s, (s_dim, h_dim))
        self.b_s_proj = np.zeros(h_dim)

        # Cross-Attention Weights
        self.w_q = rng.uniform(-0.1, 0.1, (h_dim, h_dim))
        self.w_k = rng.uniform(-0.1, 0.1, (h_dim, h_dim))
        self.w_v = rng.uniform(-0.1, 0.1, (h_dim, h_dim))

        # Final Classification Head (Hidden -> Risk Score Logit)
        self.w_classifier = rng.uniform(-0.1, 0.1, (h_dim * 2, 1))
        self.b_classifier = np.array([0.0])

    def forward(
        self, vision_features: np.ndarray, sensor_embedding: np.ndarray
    ) -> Dict[str, Any]:
        """
        Args:
            vision_features: (v_dim,) float array from YOLOv8-Pose
            sensor_embedding: (s_dim,) float array from PatchTST
        Returns:
            dict containing risk score, confidence, and modality attention weights
        """
        # 1. Project to shared dimension
        h_v = np.tanh(np.matmul(vision_features, self.w_v_proj) + self.b_v_proj)  # (h_dim,)
        h_s = np.tanh(np.matmul(sensor_embedding, self.w_s_proj) + self.b_s_proj)  # (h_dim,)

        # Stack as 2 modality tokens: [Vision, Sensor] -> (2, h_dim)
        tokens = np.vstack([h_v, h_s])

        # 2. Cross-modal Attention
        Q = np.matmul(tokens, self.w_q)  # (2, h_dim)
        K = np.matmul(tokens, self.w_k)
        V = np.matmul(tokens, self.w_v)

        scores = np.matmul(Q, K.T) / np.sqrt(self.config.hidden_dim)  # (2, 2)
        attn_matrix = softmax(scores, axis=-1)  # (2, 2)
        attended = np.matmul(attn_matrix, V)  # (2, h_dim)

        # 3. Concatenate attended representations
        fused_vec = attended.flatten()  # (2 * h_dim,)

        # 4. Compute risk logit & probability
        raw_logit = np.matmul(fused_vec, self.w_classifier) + self.b_classifier
        logit = float(raw_logit.item() if hasattr(raw_logit, "item") else raw_logit[0])
        risk_prob = 1.0 / (1.0 + np.exp(-logit))  # Sigmoid

        # Modality contribution analysis
        camera_weight = float(attn_matrix[0, 0] + attn_matrix[1, 0]) / 2.0
        sensor_weight = float(attn_matrix[0, 1] + attn_matrix[1, 1]) / 2.0
        agreement = float(1.0 - abs(attn_matrix[0, 0] - attn_matrix[1, 1]))

        return {
            "risk_score": float(np.clip(risk_prob, 0.0, 1.0)),
            "camera_contribution": camera_weight,
            "sensor_contribution": sensor_weight,
            "modality_agreement": agreement,
            "attention_matrix": attn_matrix.tolist(),
        }

    def export_json(self, filepath: Path) -> None:
        """Exports the model configuration and weights for on-device / runtime loading."""
        payload = {
            "config": asdict(self.config),
            "weights": {
                "w_v_proj": self.w_v_proj.tolist(),
                "b_v_proj": self.b_v_proj.tolist(),
                "w_s_proj": self.w_s_proj.tolist(),
                "b_s_proj": self.b_s_proj.tolist(),
                "w_q": self.w_q.tolist(),
                "w_k": self.w_k.tolist(),
                "w_v": self.w_v.tolist(),
                "w_classifier": self.w_classifier.tolist(),
                "b_classifier": self.b_classifier.tolist(),
            },
        }
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        print(f"Exported fusion model weights to {filepath}")


def run_pipeline() -> None:
    print("=" * 60)
    print("MedSync Multimodal Fusion Pipeline (YOLOv8-Pose + PatchTST)")
    print("=" * 60)

    # 1. Initialize models
    fusion_cfg = FusionModelConfig()
    fusion_model = CrossModalAttentionFusion(fusion_cfg)
    
    tst_cfg = PatchTSTConfig(input_channels=6, patch_size=16, d_model=64)
    sensor_encoder = PatchTSTEncoder(tst_cfg)

    # 2. Simulate multi-modal input
    mock_imu_window = np.random.randn(120, 6).astype(np.float32)
    sensor_out = sensor_encoder.encode(mock_imu_window)
    imu_embedding = sensor_out["embedding"]

    mock_vision_features = np.array([
        14.2,   # knee valgus angle (degrees)
        0.045,  # trunk lateral shift (normalised)
        65.0,   # hip-knee flexion angle (degrees)
        0.94,   # overall pose confidence
        0.5, 0.7, 0.5, 0.9, # left/right knee coordinates
        0.5, 0.95, 0.5, 0.95 # left/right ankle coordinates
    ], dtype=np.float32)

    # 3. Perform Cross-Modal Fusion
    result = fusion_model.forward(mock_vision_features, imu_embedding)

    print("\nInference Results:")
    print(f"  Fused Risk Score:      {result['risk_score']:.4f}")
    print(f"  Camera Contribution:   {result['camera_contribution']:.2%}")
    print(f"  Sensor Contribution:   {result['sensor_contribution']:.2%}")
    print(f"  Modality Agreement:    {result['modality_agreement']:.2%}")
    print(f"  Attention Matrix:      {result['attention_matrix']}")

    # 4. Export artifacts
    export_path = Path(__file__).resolve().parents[2] / "artifacts" / "fusion_model_v1.json"
    fusion_model.export_json(export_path)
    print("\nMultimodal fusion pipeline complete!")


if __name__ == "__main__":
    run_pipeline()
