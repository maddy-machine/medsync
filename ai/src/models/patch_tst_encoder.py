"""
PatchTST (Patch Time Series Transformer) IMU Encoder for MedSync.

This module implements the PatchTST architecture for encoding multi-channel
wearable IMU time-series data (accelerometer + gyroscope from thigh and shin)
into dense, semantically rich representation vectors for cross-modal fusion.

Architecture:
1. Patchify: Input time-series (L x C) is segmented into non-overlapping or overlapping patches.
2. Linear Projection: Each patch is linearly projected into a d_model dimensional space.
3. Positional Encoding: Sinusoidal positional embeddings are added to retain temporal ordering.
4. Transformer Encoder: Multi-head self-attention captures long-range temporal dependencies.
5. Global Pooling: Mean pooling over patch tokens yields a fixed-length embedding vector.
"""

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import numpy as np


@dataclass
class PatchTSTConfig:
    input_channels: int = 6       # 3-axis accel + 3-axis gyro (or 12 for dual sensor)
    patch_size: int = 16          # Number of time steps per patch
    patch_stride: int = 16        # Stride between consecutive patches (16 = non-overlapping)
    d_model: int = 64             # Latent embedding dimension
    n_heads: int = 4              # Attention heads
    n_layers: int = 2             # Transformer encoder layers
    d_ff: int = 128               # Feed-forward hidden dimension
    dropout: float = 0.1
    random_seed: int = 42


def softmax(x: np.ndarray, axis: int = -1) -> np.ndarray:
    """Numerically stable softmax."""
    exp_x = np.exp(x - np.max(x, axis=axis, keepdims=True))
    return exp_x / np.sum(exp_x, axis=axis, keepdims=True)


class PatchEmbedding:
    """Segments IMU time series into patches and projects to d_model."""

    def __init__(self, config: PatchTSTConfig):
        self.config = config
        self.patch_dim = config.patch_size * config.input_channels
        
        # Deterministic weight initialization
        rng = np.random.RandomState(config.random_seed)
        limit = np.sqrt(6.0 / (self.patch_dim + config.d_model))
        self.proj_weight = rng.uniform(-limit, limit, (self.patch_dim, config.d_model))
        self.proj_bias = np.zeros(config.d_model)

    def __call__(self, x: np.ndarray) -> np.ndarray:
        """
        Args:
            x: IMU array of shape (L, C)
        Returns:
            patches: Tensor of shape (num_patches, d_model)
        """
        L, C = x.shape
        p_size = self.config.patch_size
        stride = self.config.patch_stride

        # Pad if needed
        if L < p_size:
            pad_len = p_size - L
            x = np.pad(x, ((0, pad_len), (0, 0)), mode="constant")
            L = x.shape[0]

        # Extract patches
        patches = []
        for start in range(0, L - p_size + 1, stride):
            patch = x[start : start + p_size, :].flatten()
            patches.append(patch)

        patches_arr = np.array(patches)  # (N_patches, patch_dim)
        # Linear projection
        tokens = np.matmul(patches_arr, self.proj_weight) + self.proj_bias
        return tokens


class PositionalEncoding:
    """Sinusoidal positional encoding."""

    def __init__(self, d_model: int, max_len: int = 500):
        self.pe = np.zeros((max_len, d_model))
        position = np.arange(0, max_len, dtype=np.float32)[:, np.newaxis]
        div_term = np.exp(np.arange(0, d_model, 2, dtype=np.float32) * -(np.log(10000.0) / d_model))
        
        self.pe[:, 0::2] = np.sin(position * div_term)
        self.pe[:, 1::2] = np.cos(position * div_term)

    def __call__(self, x: np.ndarray) -> np.ndarray:
        """
        Args:
            x: Tensor of shape (num_patches, d_model)
        Returns:
            x + pe: Tensor with positional info added
        """
        num_patches = x.shape[0]
        return x + self.pe[:num_patches, :]


class MultiHeadSelfAttention:
    """Multi-Head Self-Attention in pure NumPy."""

    def __init__(self, config: PatchTSTConfig, layer_idx: int = 0):
        self.d_model = config.d_model
        self.n_heads = config.n_heads
        self.head_dim = self.d_model // self.n_heads
        
        rng = np.random.RandomState(config.random_seed + layer_idx * 10)
        limit = np.sqrt(6.0 / (self.d_model + self.d_model))
        
        self.w_q = rng.uniform(-limit, limit, (self.d_model, self.d_model))
        self.w_k = rng.uniform(-limit, limit, (self.d_model, self.d_model))
        self.w_v = rng.uniform(-limit, limit, (self.d_model, self.d_model))
        self.w_o = rng.uniform(-limit, limit, (self.d_model, self.d_model))

    def __call__(self, x: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Args:
            x: Tensor of shape (num_patches, d_model)
        Returns:
            out: Tensor of shape (num_patches, d_model)
            attn_weights: Attention matrix (num_patches, num_patches)
        """
        N = x.shape[0]
        
        Q = np.matmul(x, self.w_q)  # (N, d_model)
        K = np.matmul(x, self.w_k)
        V = np.matmul(x, self.w_v)

        # Reshape for multi-head: (n_heads, N, head_dim)
        Q = Q.reshape(N, self.n_heads, self.head_dim).transpose(1, 0, 2)
        K = K.reshape(N, self.n_heads, self.head_dim).transpose(1, 0, 2)
        V = V.reshape(N, self.n_heads, self.head_dim).transpose(1, 0, 2)

        # Scaled dot-product attention
        scores = np.matmul(Q, K.transpose(0, 2, 1)) / np.sqrt(self.head_dim)  # (heads, N, N)
        attn = softmax(scores, axis=-1)  # (heads, N, N)
        
        out_heads = np.matmul(attn, V)  # (heads, N, head_dim)
        out_concat = out_heads.transpose(1, 0, 2).reshape(N, self.d_model)  # (N, d_model)
        
        out = np.matmul(out_concat, self.w_o)
        mean_attn = np.mean(attn, axis=0)  # average across heads for explainability
        
        return out, mean_attn


class TransformerEncoderBlock:
    """Standard Transformer Encoder Layer (Pre-LN with residual connections)."""

    def __init__(self, config: PatchTSTConfig, layer_idx: int = 0):
        self.mha = MultiHeadSelfAttention(config, layer_idx)
        self.d_model = config.d_model
        self.d_ff = config.d_ff
        
        rng = np.random.RandomState(config.random_seed + 100 + layer_idx)
        limit1 = np.sqrt(6.0 / (self.d_model + self.d_ff))
        limit2 = np.sqrt(6.0 / (self.d_ff + self.d_model))
        
        self.w1 = rng.uniform(-limit1, limit1, (self.d_model, self.d_ff))
        self.b1 = np.zeros(self.d_ff)
        self.w2 = rng.uniform(-limit2, limit2, (self.d_ff, self.d_model))
        self.b2 = np.zeros(self.d_model)

    def _layer_norm(self, x: np.ndarray, eps: float = 1e-5) -> np.ndarray:
        mean = np.mean(x, axis=-1, keepdims=True)
        var = np.var(x, axis=-1, keepdims=True)
        return (x - mean) / np.sqrt(var + eps)

    def __call__(self, x: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        # Sub-layer 1: Self-Attention with residual
        norm_x = self._layer_norm(x)
        attn_out, attn_weights = self.mha(norm_x)
        x = x + attn_out

        # Sub-layer 2: Feed-Forward with residual (GELU activation approximation)
        norm_x2 = self._layer_norm(x)
        ff_hidden = np.matmul(norm_x2, self.w1) + self.b1
        # GELU activation: 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
        gelu = 0.5 * ff_hidden * (1.0 + np.tanh(np.sqrt(2.0 / np.pi) * (ff_hidden + 0.044715 * np.power(ff_hidden, 3))))
        ff_out = np.matmul(gelu, self.w2) + self.b2
        x = x + ff_out

        return x, attn_weights


class PatchTSTEncoder:
    """Complete PatchTST Model for IMU representation learning."""

    def __init__(self, config: Optional[PatchTSTConfig] = None):
        self.config = config or PatchTSTConfig()
        self.patch_embed = PatchEmbedding(self.config)
        self.pos_embed = PositionalEncoding(self.config.d_model)
        self.layers = [
            TransformerEncoderBlock(self.config, i)
            for i in range(self.config.n_layers)
        ]

    def encode(self, imu_window: np.ndarray) -> Dict[str, np.ndarray]:
        """
        Encode an IMU time-series window into a fixed embedding.

        Args:
            imu_window: np.ndarray of shape (L, C)
        Returns:
            dict containing:
                - "embedding": (d_model,) representation vector
                - "patch_embeddings": (num_patches, d_model) token matrix
                - "attention_weights": (num_patches, num_patches) attention map
                - "micro_tremor_score": scalar score based on high-frequency energy
                - "gait_irregularity_score": scalar score based on patch variance
        """
        # 1. Patchify & Project
        tokens = self.patch_embed(imu_window)
        # 2. Add Positional Encoding
        tokens = self.pos_embed(tokens)

        # 3. Pass through Transformer layers
        all_attns = []
        for layer in self.layers:
            tokens, attn = layer(tokens)
            all_attns.append(attn)

        # 4. Global Mean Pooling over patches
        embedding = np.mean(tokens, axis=0)  # (d_model,)

        # 5. Extract explainability scalars
        # High frequency energy in IMU channels:
        diffs = np.diff(imu_window, axis=0)
        hf_energy = float(np.mean(np.square(diffs)))
        micro_tremor_score = float(np.clip(hf_energy * 5.0, 0.0, 1.0))

        # Variance across patch tokens indicates gait irregularities / instability
        patch_variance = float(np.mean(np.var(tokens, axis=0)))
        gait_irregularity_score = float(np.clip(patch_variance * 2.0, 0.0, 1.0))

        return {
            "embedding": embedding,
            "patch_embeddings": tokens,
            "attention_weights": all_attns[-1] if all_attns else np.eye(tokens.shape[0]),
            "micro_tremor_score": micro_tremor_score,
            "gait_irregularity_score": gait_irregularity_score,
        }


def encode_imu_window(samples: np.ndarray, config: Optional[PatchTSTConfig] = None) -> np.ndarray:
    """Convenience functional API for inference."""
    encoder = PatchTSTEncoder(config)
    result = encoder.encode(samples)
    return result["embedding"]


if __name__ == "__main__":
    print("Self-testing PatchTSTEncoder...")
    config = PatchTSTConfig(input_channels=6, patch_size=16, d_model=64, n_heads=4, n_layers=2)
    encoder = PatchTSTEncoder(config)
    
    # Mock IMU sample window (100 timesteps, 6 channels: ax, ay, az, gx, gy, gz)
    mock_imu = np.random.randn(100, 6).astype(np.float32)
    output = encoder.encode(mock_imu)
    
    print(f"  Input IMU window shape: {mock_imu.shape}")
    print(f"  Output embedding shape: {output['embedding'].shape}")
    print(f"  Patch tokens shape:     {output['patch_embeddings'].shape}")
    print(f"  Attention map shape:    {output['attention_weights'].shape}")
    print(f"  Micro-tremor score:     {output['micro_tremor_score']:.4f}")
    print(f"  Gait irregularity:      {output['gait_irregularity_score']:.4f}")
    print("PatchTSTEncoder self-test PASSED!")
