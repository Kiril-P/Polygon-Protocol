"""Procedural music: gameplay tracks and layered boss themes.

Everything is rendered from note data so the loops are sample-exact (reverb
and delay tails are folded back onto the loop start).
"""
from synth import *

# ------------------------------------------------------------------ voices
_cache = {}


def _cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def kick(punch=1.0, tail=0.16):
    def make():
        d = 0.42
        f = sweep_(170, 46, d, 0.18)
        body = sine(f) * expdecay(d, tail)
        click = hp(noise(0.01), 2000) * np.linspace(1, 0, int(0.01 * SR))
        x = sat(body * 1.1, 1.4 + punch * 0.4)
        x[:len(click)] += click * 0.25 * punch
        return fade(x, 0.0, 0.01)
    return _cached(("kick", punch, tail), make)


def sweep_(f0, f1, dur, shape):
    t = np.linspace(0, 1, int(dur * SR)) ** shape
    return f0 * (f1 / f0) ** t


def snare(tone=190, body=0.6, tail=0.14):
    def make():
        d = 0.35
        nz = bp(noise(d), 1500, 9000) * expdecay(d, tail * 0.55)
        t_ = sine(sweep_(tone * 1.6, tone, d, 0.2)) * expdecay(d, 0.06) * body
        return fade(sat(nz * 0.7 + t_, 1.3), 0, 0.02)
    return _cached(("snare", tone, body, tail), make)


def clap():
    def make():
        d = 0.3
        x = np.zeros(int(d * SR))
        for k in range(4):
            seg = bp(noise(0.05), 900, 4500) * expdecay(0.05, 0.012)
            mix_into(x, seg, int(k * 0.011 * SR))
        tailn = bp(noise(d), 900, 4000) * expdecay(d, 0.07)
        mix_into(x, tailn * 0.8, int(0.04 * SR))
        return fade(x, 0, 0.02)
    return _cached(("clap",), make)


def hat(open_=False):
    def make():
        d = 0.28 if open_ else 0.06
        x = hp(noise(d), 7000, 3) * expdecay(d, 0.09 if open_ else 0.015)
        return fade(x, 0, 0.01)
    return _cached(("hat", open_), make)


def tom(freq=120):
    def make():
        d = 0.4
        x = sine(sweep_(freq * 1.6, freq, d, 0.3)) * expdecay(d, 0.15)
        return fade(sat(x, 1.5), 0, 0.02)
    return _cached(("tom", freq), make)


def bass_note(m, dur, drive=2.0, cut=900, sub=True):
    def make():
        f = midi(m)
        total = dur + 0.06
        x = saw(f, total) * 0.55 + square(f, total, 0.5) * 0.3
        env = adsr(dur, 0.004, 0.08, 0.8, 0.05, total=total)
        bright = expdecay(total, 0.12)
        dark = lp(x, cut * 0.35, 2)
        lit = lp(x, cut * 2.2, 2)
        y = dark * (1 - bright) + lit * bright
        if sub:
            y = y + sine(f, total) * 0.55
        return lp(sat(y * env, drive), 3400, 2)
    return _cached(("bass", m, round(dur, 3), drive, cut, sub), make)


def pad_chord(notes, dur, cut=1800, voices=4, spread=0.012, a=0.25, r=0.4):
    key = ("pad", tuple(notes), round(dur, 3), cut, voices, spread, a, r)

    def make():
        total = dur + r
        out = np.zeros((2, int(total * SR)))
        env = adsr(dur, a, 0.3, 0.8, r, total=total)
        for ni, m in enumerate(notes):
            for v in range(voices):
                det = (v - (voices - 1) / 2) * spread
                sig = saw(midi(m) * (1 + det), total)
                pan = (v / max(voices - 1, 1))
                out[0] += sig * (1 - pan) * 0.5
                out[1] += sig * pan * 0.5
        out = lp(out[0], cut, 2) * 0 + np.array([lp(out[0], cut, 2), lp(out[1], cut, 2)])
        out *= env * 0.16 / max(len(notes) / 3, 1)
        return out
    return _cached(key, make)


def pluck(m, dur=0.3, cut=4500, shape="saw"):
    def make():
        f = midi(m)
        total = dur
        sig = saw(f, total) if shape == "saw" else square(f, total, 0.4)
        sig = sig * 0.6 + saw(f * 1.006, total) * 0.4
        env = expdecay(total, dur * 0.35)
        bright = expdecay(total, 0.07)
        dark = lp(sig, 700, 2)
        lit = lp(sig, cut, 2)
        y = (dark * (1 - bright) + lit * bright) * env
        return fade(y, 0.001, 0.01)
    return _cached(("pluck", m, round(dur, 3), cut, shape), make)


def lead_note(m, dur, vib=0.0045, cut=3800, a=0.01, wave="saw"):
    def make():
        total = dur + 0.25
        t = t_axis(total)
        vibr = 1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.25, 0, 1)
        f = midi(m) * vibr
        if wave == "saw":
            sig = saw(f) * 0.5 + saw(f * 1.007) * 0.35 + sine(f * 0.5) * 0.25
        else:
            sig = square(f, None, 0.45) * 0.45 + saw(f * 1.005) * 0.3 + sine(f) * 0.3
        sig = lp(sig, cut, 2)
        env = adsr(dur, a, 0.12, 0.75, 0.22, total=total)
        return sat(sig * env, 1.4) * 0.6
    return _cached(("lead", m, round(dur, 3), vib, cut, wave), make)


def choir(notes, dur):
    """Formant-filtered saw stack: breathy 'ooh/aah' pad for the final boss."""
    def make():
        total = dur + 0.8
        out = np.zeros((2, int(total * SR)))
        env = adsr(dur, 0.6, 0.4, 0.85, 0.8, total=total)
        for m in notes:
            for v, pan in ((0.996, 0.2), (1.0, 0.5), (1.004, 0.8)):
                sig = saw(midi(m) * v, total)
                voice = bp(sig, 330, 480, 2) * 1.2 + bp(sig, 700, 950, 2) * 0.8 + bp(sig, 2200, 2700, 2) * 0.25
                out[0] += voice * (1 - pan)
                out[1] += voice * pan
        out *= env * 0.2 / max(len(notes) / 3, 1)
        return out
    return _cached(("choir", tuple(notes), round(dur, 3)), make)


def riser(dur, lo=300, hi=9000):
    t = t_axis(dur)
    x = lp(noise(dur), sweep_(lo, hi, dur, 1.7)) * (t / dur) ** 1.8
    return x * 0.6


def impact(dur=1.4):
    def make():
        b = sine(sweep_(120, 34, dur, 0.4)) * expdecay(dur, 0.35)
        c = lp(noise(dur), sweep_(6000, 200, dur, 0.4)) * expdecay(dur, 0.28) * 0.7
        return fade(sat(b + c, 1.6), 0, 0.05)
    return _cached(("impact", dur), make)


# ------------------------------------------------------------------ engine
class Track:
    def __init__(self, bpm, bars, tail=3.0):
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4.0
        self.bar = self.step * 16
        self.N = int(round(self.bar * bars * SR))
        self.tail = int(tail * SR)
        self.stems = {}
        self.kicks = []

    def stem(self, name):
        if name not in self.stems:
            self.stems[name] = np.zeros((2, self.N + self.tail))
        return self.stems[name]

    def at(self, bar, step):
        return int(round((bar * 16 + step) * self.step * SR))

    def put(self, stem, sample, bar, step, gain=1.0, pan=0.0):
        dst = self.stem(stem)
        s = sample if sample.ndim == 2 else np.array([sample, sample])
        if pan != 0.0 and sample.ndim == 1:
            l = np.sqrt((1 - pan) / 2.0) * 1.414
            r = np.sqrt((1 + pan) / 2.0) * 1.414
            s = np.array([sample * l, sample * r])
        mix_into(dst, s * gain, self.at(bar, step))

    def duck(self, stem_names, depth=0.55, rel=0.16):
        """Sidechain: pump the given stems from the recorded kick hits."""
        curve = np.ones(self.N + self.tail)
        for k in self.kicks:
            seg = min(int(0.4 * SR), len(curve) - k)
            if seg <= 0:
                continue
            t = np.arange(seg) / SR
            dip = 1 - depth * np.exp(-t / rel)
            curve[k:k + seg] = np.minimum(curve[k:k + seg], dip)
        for nm in stem_names:
            if nm in self.stems:
                self.stems[nm] *= curve

    def fold(self):
        """Fold tails onto the loop start and cut to length -> seamless loop."""
        for nm, x in list(self.stems.items()):
            body = x[:, :self.N].copy()
            tail = x[:, self.N:]
            L = min(tail.shape[1], self.N)
            body[:, :L] += tail[:, :L]
            self.stems[nm] = body


def drums(tr, bar, pattern, stem="drums", vel=1.0, kick_kw=None, swing=0.0, ghost=True):
    kw = kick_kw or {}
    for i, c in enumerate(pattern["kick"]):
        if c != ".":
            g = 1.0 if c == "X" else 0.7
            tr.put(stem, kick(**kw), bar, i, 0.95 * g * vel)
            tr.kicks.append(tr.at(bar, i))
    for i, c in enumerate(pattern.get("snare", "." * 16)):
        if c != ".":
            tr.put(stem, snare(**pattern.get("snare_kw", {})), bar, i, (0.8 if c == "X" else 0.35) * vel, pan=0.05)
    for i, c in enumerate(pattern.get("clap", "." * 16)):
        if c != ".":
            tr.put(stem, clap(), bar, i, 0.5 * vel, pan=-0.05)
    for i, c in enumerate(pattern.get("hat", "." * 16)):
        if c != ".":
            tr.put(stem, hat(False), bar, i, (0.32 if c == "x" else 0.2) * vel, pan=0.25 if i % 4 else 0.1)
    for i, c in enumerate(pattern.get("open", "." * 16)):
        if c != ".":
            tr.put(stem, hat(True), bar, i, 0.26 * vel, pan=-0.25)
    for i, c in enumerate(pattern.get("tom", "." * 16)):
        if c != ".":
            fr = pattern.get("tom_freq", 120) * (1.0 if c == "x" else 1.35)
            tr.put(stem, tom(fr), bar, i, 0.55 * vel, pan=-0.2 if c == "x" else 0.2)


def render_chords(tr, bar, notes, stem="pad", bars=1.0, gain=1.0, **kw):
    dur = tr.bar * bars
    tr.put(stem, pad_chord(notes, dur, **kw), bar, 0, gain)


def bass_line(tr, bar, root, pattern, stem="bass", gain=1.0, **kw):
    for step, off, ln in pattern:
        tr.put(stem, bass_note(root + off, ln * tr.step * 0.95, **kw), bar, step, gain)


def arp_line(tr, bar, tones, pattern, stem="arp", gain=1.0, dur_steps=2.0, **kw):
    for i, idx in enumerate(pattern):
        if idx is None:
            continue
        m = tones[idx % len(tones)] + 12 * (idx // len(tones))
        tr.put(stem, pluck(m, dur_steps * tr.step * 1.6, **kw), bar, i, gain * (1.0 if i % 4 == 0 else 0.78), pan=((i % 4) - 1.5) * 0.35)


def lead_line(tr, bar, notes, stem="lead", gain=1.0, **kw):
    for step, m, ln in notes:
        tr.put(stem, lead_note(m, ln * tr.step * 0.97, **kw), bar, step, gain, pan=0.0)


def finalize_stems(tr, fx):
    """Per-stem effects (applied before fold so tails wrap)."""
    for nm, x in tr.stems.items():
        e = fx.get(nm)
        if not e:
            continue
        if "echo" in e:
            d, fb, mx = e["echo"]
            y = echo(x, d, fb, mx, 5)
            y = y[:, :x.shape[1]]
            x = y
        if "reverb" in e:
            mx, dur, dec = e["reverb"]
            y = reverb(x, mx, dur, dec, 5500)
            x = y[:, :x.shape[1]]
        tr.stems[nm] = x


def to_ogg(path, stereo, bitrate="192k"):
    import subprocess, tempfile, os
    tmp = tempfile.mktemp(suffix=".wav")
    write_wav(tmp, stereo)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "vorbis", "-strict", "-2",
                    "-b:a", bitrate, path], check=True)
    os.remove(tmp)
