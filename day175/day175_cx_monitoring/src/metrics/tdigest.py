"""
Minimal T-Digest implementation for accurate percentile estimation.
O(1) amortized insert, ~1 KB memory per tracker regardless of data volume.
"""
import math
from dataclasses import dataclass, field

@dataclass
class _Centroid:
    mean  : float
    count : int

class TDigest:
    """Streaming percentile estimator using T-Digest algorithm."""
    def __init__(self, compression: float = 100.0):
        self._comp      = compression
        self._centroids : list[_Centroid] = []
        self._total     = 0

    def add(self, value: float, count: int = 1):
        self._total += count
        self._centroids.append(_Centroid(value, count))
        if len(self._centroids) > self._comp * 10:
            self._compress()

    def _compress(self):
        self._centroids.sort(key=lambda c: c.mean)
        merged, q_limit_s = [], 0.0
        q = 0.0
        for c in self._centroids:
            q_next = q + c.count / self._total
            # limit based on k-function (linear scale)
            limit = 2 * q * (1 - q)
            if merged and (q - q_limit_s + c.count / self._total) <= limit + 1e-9:
                merged[-1].mean  = (merged[-1].mean * merged[-1].count + c.mean * c.count) / (merged[-1].count + c.count)
                merged[-1].count += c.count
            else:
                merged.append(_Centroid(c.mean, c.count))
                q_limit_s = q
            q = q_next
        self._centroids = merged

    def percentile(self, p: float) -> float:
        """Return the p-th percentile (0–100)."""
        if not self._centroids:
            return 0.0
        self._compress()
        target = p / 100.0 * self._total
        cumul  = 0.0
        for i, c in enumerate(self._centroids):
            mid = cumul + c.count / 2.0
            if mid >= target:
                if i == 0:
                    return c.mean
                prev_mid = cumul - self._centroids[i-1].count / 2.0
                frac = (target - prev_mid) / (mid - prev_mid) if mid != prev_mid else 0.5
                frac = max(0.0, min(1.0, frac))
                return self._centroids[i-1].mean + frac * (c.mean - self._centroids[i-1].mean)
            cumul += c.count
        return self._centroids[-1].mean

    def count(self) -> int:
        return self._total
