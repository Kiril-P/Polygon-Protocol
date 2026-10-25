"""Loudness report for the game's SFX: file level plus the db the game applies.

    /tmp/audio-venv/bin/python tools/audio/loudness.py

Columns are measured on the rendered WAVs in assets/audio/sfx, after the per-sound "db" in
AudioManager.SFX. Peak and RMS are dBFS; centroid is the spectral centroid in Hz at the
sound's default pitch range (high = shrill, over about 3000 Hz is what tires the ear).
Sorted loudest peak first, so what sticks out is at the top.
"""
import re
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / "scripts/audio_manager.gd").read_text()
ENTRY = re.compile(r'"(\w+)": \{"files": \[([^\]]*)\], "db": (-?[\d.]+), "pitch": \[([\d., ]+)\], '
                   r'"cooldown": ([\d.]+), "voices": (\d+)')


def load(name: str):
    with wave.open(str(ROOT / "assets/audio/sfx" / f"{name}.wav")) as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype={1: np.int8, 2: np.int16, 4: np.int32}[w.getsampwidth()])
        x = raw.astype(np.float64) / float(2 ** (8 * w.getsampwidth() - 1))
        return x.reshape(-1, w.getnchannels()).mean(axis=1), w.getframerate()


def main() -> int:
    rows = []
    for m in ENTRY.finditer(SRC):
        key, files, db = m.group(1), re.findall(r'"(\w+)"', m.group(2)), float(m.group(3))
        pitch = [float(p) for p in m.group(4).split(",")]
        peaks, rmss, cents, dur = [], [], [], 0.0
        for f in files:
            x, sr = load(f)
            peaks.append(20 * np.log10(np.abs(x).max() + 1e-9))
            rmss.append(20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9))
            mag = np.abs(np.fft.rfft(x))
            freq = np.fft.rfftfreq(len(x), 1 / sr)
            cents.append((mag * freq).sum() / (mag.sum() + 1e-9) * np.mean(pitch))
            dur = max(dur, len(x) / sr)
        rows.append((max(peaks) + db, float(np.mean(rmss)) + db, float(np.mean(cents)), dur, float(m.group(5)), int(m.group(6)), key))
    rows.sort(reverse=True)
    print(f"{'sfx':<18}{'peak':>7}{'rms':>7}{'centroid':>10}{'dur':>6}{'cool':>6}{'vox':>4}")
    for pk, rms, cen, dur, cd, vox, key in rows:
        print(f"{key:<18}{pk:>7.1f}{rms:>7.1f}{cen:>9.0f}H{dur:>6.2f}{cd:>6.2f}{vox:>4}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
