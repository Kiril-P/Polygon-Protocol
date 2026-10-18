"""Tiny numpy/scipy synth toolkit used to render Polygon Protocol's SFX and music.

Run via tools/audio/render_all.py (see README in that file). All output is
generated from code so the sound can be tuned and re-rendered reproducibly.
"""
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name):
    """'A2' -> midi number."""
    base = name[:-1]
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE[base]


# ---------------------------------------------------------------- envelopes
def adsr(dur, a=0.005, d=0.05, s=0.7, r=0.05, total=None):
    total = int((total if total is not None else dur + r) * SR)
    e = np.zeros(total)
    na, nd = int(a * SR), int(d * SR)
    nh = int(dur * SR)
    for i in range(min(na, total)):
        e[i] = i / max(na, 1)
    for i in range(na, min(na + nd, total)):
        e[i] = 1.0 - (1.0 - s) * (i - na) / max(nd, 1)
    e[na + nd:min(nh, total)] = s
    nr = total - nh
    if nr > 0 and nh > 0:
        start = e[nh - 1] if nh - 1 < total else s
        e[nh:] = start * (1.0 - np.arange(nr) / nr) ** 2
    return e


def expdecay(dur, tau):
    t = t_axis(dur)
    return np.exp(-t / tau)


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ---------------------------------------------------------------- oscillators
def phase_from_freq(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def sine(freq, dur=None):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    return np.sin(phase_from_freq(freq))


def saw(freq, dur=None, detune=0.0):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    ph = (np.cumsum(freq * (1.0 + detune)) / SR) % 1.0
    # polyBLEP-ish smoothing via band-limiting: cheap, slight lowpass afterwards
    return 2.0 * ph - 1.0


def square(freq, dur=None, pw=0.5):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    ph = (np.cumsum(freq) / SR) % 1.0
    return np.where(ph < pw, 1.0, -1.0)


def tri(freq, dur=None):
    if np.isscalar(freq):
        freq = np.full(int(dur * SR), float(freq))
    ph = (np.cumsum(freq) / SR) % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


# ---------------------------------------------------------------- filters
def lp(x, cutoff, order=2):
    if np.isscalar(cutoff):
        sos = signal.butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos")
        return signal.sosfilt(sos, x)
    return lp_sweep(x, cutoff)


def hp(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp_sweep(x, cutoff_curve, block=256):
    """Time-varying lowpass (block-wise biquad with state carry)."""
    out = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        c = float(np.clip(cutoff_curve[min(i, len(cutoff_curve) - 1)], 40, SR * 0.45))
        sos = signal.butter(2, c, "low", fs=SR, output="sos")
        if zi is None or zi.shape != (sos.shape[0], 2):
            zi = np.zeros((sos.shape[0], 2))
        seg, zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
        out[i:i + block] = seg
    return out


# ---------------------------------------------------------------- effects
def sat(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def bitcrush(x, bits=6, down=4):
    q = 2 ** bits
    y = np.round(x * q) / q
    return np.repeat(y[::down], down)[:len(x)]


def echo(x, delay, feedback=0.4, mix=0.35, taps=6):
    """Feedback delay; works on mono or stereo (last axis = time)."""
    d = int(delay * SR)
    out = np.zeros(x.shape[:-1] + (x.shape[-1] + d * taps,))
    out[..., :x.shape[-1]] += x
    for k in range(1, taps + 1):
        out[..., d * k:d * k + x.shape[-1]] += x * (feedback ** k) * mix
    return out


def reverb_ir(dur=1.6, decay=3.0, damp=6000, stereo=True):
    n_ = int(dur * SR)
    t = np.arange(n_) / SR
    chans = []
    for _ in range(2 if stereo else 1):
        ir = rng.normal(0, 1, n_) * np.exp(-t * decay)
        ir = lp(ir, damp, 1)
        ir[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        chans.append(ir)
    return np.array(chans)


_IR_CACHE = {}


def reverb(x, mix=0.25, dur=1.6, decay=3.0, damp=6000):
    key = (dur, decay, damp)
    if key not in _IR_CACHE:
        _IR_CACHE[key] = reverb_ir(dur, decay, damp, True)
    ir = _IR_CACHE[key]
    if x.ndim == 1:
        wet = np.array([signal.fftconvolve(x, ir[0]), signal.fftconvolve(x, ir[1])])
        wet *= 1.0 / (np.sqrt(np.sum(ir[0] ** 2)) + 1e-9) * 0.5
        dry = np.pad(x, (0, wet.shape[1] - len(x)))
        return np.array([dry, dry]) * (1 - mix) + wet * mix
    wl = signal.fftconvolve(x[0], ir[0])
    wr = signal.fftconvolve(x[1], ir[1])
    wet = np.array([wl, wr]) / (np.sqrt(np.sum(ir[0] ** 2)) + 1e-9) * 0.5
    dry = np.pad(x, ((0, 0), (0, wet.shape[1] - x.shape[1])))
    return dry * (1 - mix) + wet * mix


def mono_reverb(x, mix=0.2, dur=0.8, decay=5.0, damp=5000):
    st = reverb(x, mix, dur, decay, damp)
    return st.mean(axis=0)


def pad_to(x, length):
    if len(x) >= length:
        return x[:length]
    return np.pad(x, (0, length - len(x)))


def mix_into(dst, src, start):
    """Add src to dst at sample offset start (mono or stereo)."""
    if start < 0:
        src = src[..., -start:]
        start = 0
    end = min(dst.shape[-1], start + src.shape[-1])
    if end <= start:
        return
    dst[..., start:end] += src[..., :end - start]


# ---------------------------------------------------------------- output
def peak_normalize(x, peak_db=-3.0):
    p = np.max(np.abs(x)) + 1e-9
    return x * (10 ** (peak_db / 20.0) / p)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    wavfile.write(path, sr, (x * 32767).astype(np.int16).T if x.ndim == 2 else (x * 32767).astype(np.int16))
