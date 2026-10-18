import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.io import wavfile
names = sys.argv[2:]
fig, axes = plt.subplots(len(names), 2, figsize=(12, 1.7 * len(names)))
base = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")
for i, nm in enumerate(names):
    sr, x = wavfile.read(os.path.join(base, nm + ".wav"))
    x = x.astype(float) / 32768
    axes[i, 0].plot(np.arange(len(x)) / sr, x, lw=0.4); axes[i, 0].set_ylabel(nm, fontsize=7)
    axes[i, 1].specgram(x, NFFT=512, Fs=sr, noverlap=384, cmap="magma"); axes[i, 1].set_ylim(0, 12000)
plt.tight_layout(); plt.savefig(sys.argv[1], dpi=70)
