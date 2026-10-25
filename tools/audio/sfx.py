"""All sound effects. Each function returns a mono float array (not normalised
to game level - AudioManager applies per-sound gain)."""
from synth import *


def sweep(f0, f1, dur, shape=1.0):
    """Exponential frequency sweep array. shape<1 front-loads the change."""
    t = np.linspace(0, 1, int(dur * SR)) ** shape
    return f0 * (f1 / f0) ** t


# ---------------------------------------------------------------- combat
def player_fire(variant=0):
    dur = 0.11
    f0 = [1250, 1150, 1350, 1200][variant]
    f = sweep(f0, f0 * 0.32, dur, 0.55)
    body = sine(f) * 0.7 + tri(f * 2.0) * 0.18
    click = noise(0.006) * np.linspace(1, 0, int(0.006 * SR))
    x = body * expdecay(dur, 0.055) * (1.0 + 0.6 * expdecay(dur, 0.01))
    x[:len(click)] += click * 0.35
    return lp(x, 6500, 1)


def enemy_hit(variant=0):
    dur = 0.07
    f = sweep([380, 330, 430][variant % 3], 120, dur, 0.5)
    x = sine(f) * expdecay(dur, 0.022)
    x += lp(noise(dur), 3000) * expdecay(dur, 0.01) * 0.45
    return fade(x, 0.0005, 0.01)


def enemy_death(variant=0, big=False):
    dur = 0.34 if not big else 0.6
    base = [190, 165, 215][variant % 3] * (0.6 if big else 1.0)
    f = sweep(base * 2.2, base * 0.35, dur, 0.4)
    x = sat(sine(f), 1.8) * expdecay(dur, 0.1 if not big else 0.18)
    nz = lp(noise(dur), sweep(7000, 400, dur, 0.5)) * expdecay(dur, 0.07 if not big else 0.14)
    x = x * 0.8 + nz * 0.9
    sub = sine(sweep(110, 38, dur, 0.5)) * expdecay(dur, 0.12) * (0.9 if big else 0.4)
    return fade(x + sub, 0.0005, 0.02)


def enemy_fire():
    dur = 0.16
    f = sweep(420, 190, dur, 0.5)
    x = square(f, pw=0.35) * 0.4 + sine(f) * 0.5
    x = lp(x, 2500) * adsr(dur, 0.002, 0.04, 0.35, 0.08, total=dur)
    return x


def bullet_bounce():
    dur = 0.12
    f = sweep(900, 1500, dur, 0.6)
    x = sine(f) * expdecay(dur, 0.04) + sine(f * 2.01) * expdecay(dur, 0.02) * 0.3
    return fade(x, 0.001, 0.02)


def bullet_explosion():
    dur = 0.55
    nz = lp(noise(dur), sweep(6000, 250, dur, 0.4)) * expdecay(dur, 0.12)
    boom = sine(sweep(140, 40, dur, 0.45)) * expdecay(dur, 0.2)
    x = sat(nz * 0.9 + boom * 1.1, 1.6)
    return fade(x, 0.0005, 0.04)


def kamikaze_alert():
    out = np.zeros(int(0.5 * SR))
    for i, st in enumerate((0.0, 0.2)):
        d = 0.12
        tone = sine(980.0, d) * 0.3 + sine(980.0 * 2, d) * 0.05
        tone = lp(tone * adsr(d, 0.01, 0.03, 0.7, 0.05, total=d), 2200)
        mix_into(out, tone, int(st * SR))
    return out


def player_hit():
    dur = 0.55
    thump = sine(sweep(210, 45, dur, 0.35)) * expdecay(dur, 0.14)
    crash = lp(noise(dur), sweep(5000, 300, dur, 0.35)) * expdecay(dur, 0.1)
    buzz = sat(saw(sweep(180, 70, dur, 0.5)), 3.0) * expdecay(dur, 0.12) * 0.35
    x = thump * 1.0 + crash * 0.8 + buzz
    x = fade(sat(x, 1.8), 0.0005, 0.05)
    return mono_reverb(x, 0.12, 0.5, 6.0)[:len(x)]


def shield_break():
    dur = 0.6
    parts = np.zeros(int(dur * SR))
    for k, fr in enumerate((1800, 2400, 3100, 3900, 5200)):
        d = 0.35 - 0.04 * k
        s_ = sine(fr * (1 + 0.01 * k), d) * expdecay(d, 0.09)
        mix_into(parts, s_ * 0.3, int(k * 0.012 * SR))
    nz = lp(hp(noise(dur), 2500), 5200) * expdecay(dur, 0.08) * 0.45
    low = sine(sweep(260, 70, dur, 0.4)) * expdecay(dur, 0.12) * 0.6
    return fade(parts + nz + low, 0.0005, 0.04)


def shield_regen():
    dur = 0.6
    f = sweep(300, 1400, dur, 1.4)
    x = sine(f) * 0.5 + sine(f * 2) * 0.2
    x *= adsr(dur * 0.8, 0.05, 0.1, 0.7, 0.2, total=dur)
    return mono_reverb(x, 0.2, 0.6, 6.0)[:len(x)]


def heal():
    notes = [n("E5"), n("G#5"), n("B5")]
    out = np.zeros(int(0.7 * SR))
    for i, m in enumerate(notes):
        d = 0.35
        tone = (sine(midi(m), d) + 0.3 * sine(midi(m) * 2, d)) * expdecay(d, 0.15)
        mix_into(out, tone * 0.5, int(i * 0.07 * SR))
    return mono_reverb(out, 0.25, 0.7, 5.0)[:len(out)]


# ---------------------------------------------------------------- movement
def dash_start():
    dur = 0.28
    nz = noise(dur)
    sweepc = sweep(400, 5500, dur, 0.6)
    x = lp(nz, sweepc) * adsr(dur * 0.7, 0.02, 0.08, 0.6, 0.12, total=dur)
    tone = sine(sweep(160, 520, dur, 0.5)) * 0.35 * expdecay(dur, 0.14)
    return fade(x * 0.9 + tone, 0.002, 0.04)


def dash_loop():
    """1.0s seamless loop: airy low whoosh + subtle hum (tail crossfaded into head)."""
    dur = 1.0
    f = int(0.08 * SR)
    N = int(dur * SR)
    raw = bp(noise(dur + 0.08), 300, 2600)
    w = np.linspace(0, 1, f)
    body = raw[:N].copy()
    body[:f] = raw[:f] * w + raw[N:N + f] * (1 - w)
    t = t_axis(dur)
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * 7 * t)
    hum = sine(110.0, dur) * 0.25 + sine(220.0, dur) * 0.12
    return body * wob * 0.6 + hum


def dash_end():
    dur = 0.2
    x = lp(noise(dur), sweep(3500, 300, dur, 0.5)) * expdecay(dur, 0.06)
    return fade(x * 0.8, 0.002, 0.03)


def dash_empty():
    dur = 0.35
    f = sweep(240, 90, dur, 0.6)
    x = sat(square(f, pw=0.3), 2.0) * 0.4 + sine(f) * 0.4
    x = lp(x, 1800) * adsr(dur * 0.8, 0.003, 0.05, 0.55, 0.12, total=dur)
    return x


def dash_ready():
    out = np.zeros(int(0.35 * SR))
    for i, m in enumerate((n("E6"), n("B6"))):
        d = 0.2
        tone = sine(midi(m), d) * expdecay(d, 0.07)
        mix_into(out, tone * 0.45, int(i * 0.06 * SR))
    return out


def player_spawn():
    dur = 0.9
    f = sweep(120, 900, dur, 1.6)
    x = (saw(f) * 0.25 + sine(f) * 0.5)
    x = lp(x, sweep(300, 6000, dur, 1.5)) * adsr(dur * 0.8, 0.3, 0.2, 0.7, 0.3, total=dur)
    return mono_reverb(x, 0.3, 0.8, 4.5)[:len(x)]


# ---------------------------------------------------------------- progress
def level_up():
    notes = [n("A4"), n("C#5"), n("E5"), n("A5")]
    out = np.zeros(int(1.1 * SR))
    for i, m in enumerate(notes):
        d = 0.5
        f = midi(m)
        tone = sine(f, d) * 0.5 + saw(f, d) * 0.12 + sine(f * 2, d) * 0.15
        tone = lp(tone, 5500) * adsr(d * 0.5, 0.004, 0.08, 0.5, 0.25, total=d)
        mix_into(out, tone, int(i * 0.075 * SR))
    return mono_reverb(out, 0.25, 0.9, 4.0)[:len(out)]


def upgrade_select():
    out = np.zeros(int(0.8 * SR))
    for m in (n("A4"), n("E5"), n("A5")):
        d = 0.45
        f = midi(m)
        tone = (sine(f, d) + 0.25 * saw(f, d) * 0 + 0.2 * sine(f * 3, d)) * expdecay(d, 0.16)
        mix_into(out, tone * 0.5, 0)
    return mono_reverb(out, 0.25, 0.8, 4.5)[:len(out)]


def combo_tick():
    d = 0.09
    x = sine(1600.0, d) * expdecay(d, 0.03) + sine(3200.0, d) * expdecay(d, 0.015) * 0.2
    return fade(x, 0.001, 0.01)


def combo_break():
    dur = 0.4
    f = sweep(700, 150, dur, 0.5)
    x = tri(f) * expdecay(dur, 0.12) * 0.7 + lp(noise(dur), 1500) * expdecay(dur, 0.04) * 0.3
    return fade(x, 0.002, 0.03)


# ---------------------------------------------------------------- UI
def ui_click():
    d = 0.09
    x = sine(sweep(1000, 700, d, 0.5)) * expdecay(d, 0.03) + sine(2000, d) * expdecay(d, 0.015) * 0.25
    return fade(x, 0.001, 0.01)


def ui_hover():
    d = 0.05
    x = sine(1900.0, d) * expdecay(d, 0.018) * 0.6
    return fade(x, 0.001, 0.008)


def pause():
    dur = 0.45
    x = lp(noise(dur), sweep(5000, 300, dur, 0.6)) * adsr(dur * 0.5, 0.01, 0.1, 0.6, 0.25, total=dur) * 0.7
    x += sine(sweep(500, 110, dur, 0.5)) * expdecay(dur, 0.16) * 0.4
    return fade(x, 0.003, 0.05)


def unpause():
    dur = 0.35
    x = lp(noise(dur), sweep(300, 5200, dur, 0.7)) * adsr(dur * 0.5, 0.05, 0.1, 0.6, 0.15, total=dur) * 0.6
    x += sine(sweep(110, 500, dur, 0.7)) * expdecay(dur, 0.15) * 0.4
    return fade(x, 0.003, 0.04)


def game_over():
    dur = 2.6
    t = t_axis(dur)
    f = sweep(330, 55, dur, 0.5)
    x = sat(saw(f) * 0.4 + sine(f) * 0.6 + saw(f * 1.01) * 0.3, 1.5)
    x = lp(x, sweep(3500, 200, dur, 0.5)) * adsr(dur * 0.4, 0.01, 0.4, 0.6, dur * 0.6, total=dur)
    nz = lp(noise(dur), sweep(4000, 150, dur, 0.4)) * expdecay(dur, 0.35) * 0.4
    x = x + nz
    y = reverb(x, 0.3, 1.5, 3.0).mean(axis=0)
    return y[:int(dur * SR) + int(0.3 * SR)]


# ---------------------------------------------------------------- bosses
def boss_spawn():
    dur = 3.0
    t = t_axis(dur)
    rise = lp(noise(dur), sweep(150, 7000, dur, 1.8)) * (t / dur) ** 1.7 * 0.8
    tone = sat(saw(sweep(55, 110, dur, 1.6)) * 0.5 + sine(sweep(55, 110, dur, 1.6)) * 0.7, 2.0) * (t / dur) ** 1.2 * 0.7
    hit_at = int(2.4 * SR)
    hit_len = int(0.6 * SR)
    out = rise * 1.0 + tone
    out[hit_at:] *= 0.0
    boom = sine(sweep(120, 32, 0.6, 0.4)) * expdecay(0.6, 0.18) + lp(noise(0.6), 800) * expdecay(0.6, 0.08) * 0.8
    out = pad_to(out, int(dur * SR) + hit_len)
    mix_into(out, sat(boom, 1.8) * 1.2, hit_at)
    return mono_reverb(out, 0.2, 1.2, 3.5)[:len(out)]


def boss_phase():
    dur = 1.5
    t = t_axis(dur)
    boom = sine(sweep(150, 38, dur, 0.4)) * expdecay(dur, 0.25)
    crash = lp(noise(dur), sweep(7000, 250, dur, 0.4)) * expdecay(dur, 0.2) * 0.9
    stab = sat(saw(midi(n("D3")), dur) + saw(midi(n("G#3")), dur) * 0.7, 2.5) * expdecay(dur, 0.25) * 0.35
    x = sat(boom * 1.1 + crash + stab, 1.5)
    return mono_reverb(x, 0.25, 1.0, 3.5)[:len(x)]


def boss_warning():
    dur = 2.0
    x = np.zeros(int(dur * SR))
    for k in range(3):
        d = 0.5
        f = sweep(520, 900, d, 1.0)
        tone = sat(saw(f) * 0.5 + square(f * 0.5) * 0.3, 1.8)
        tone = lp(tone, 3200) * adsr(d * 0.8, 0.02, 0.05, 0.8, 0.12, total=d) * 0.6
        mix_into(x, tone, int(k * 0.62 * SR))
    return x


def boss_death():
    dur = 4.0
    t = t_axis(dur)
    x = np.zeros(int(dur * SR) + SR)
    for k in range(7):
        st = int((k * 0.22 + rng.uniform(0, 0.06)) * SR)
        d = 1.0
        b = sine(sweep(130 - 8 * k, 36, d, 0.4)) * expdecay(d, 0.22) + lp(noise(d), sweep(6000, 200, d, 0.4)) * expdecay(d, 0.18) * 0.9
        mix_into(x, sat(b, 1.6) * (0.5 + 0.1 * k), st)
    final_at = int(1.7 * SR)
    fd = 2.3
    fb = sine(sweep(100, 28, fd, 0.35)) * expdecay(fd, 0.6) * 1.2 + lp(noise(fd), sweep(5000, 120, fd, 0.35)) * expdecay(fd, 0.5)
    mix_into(x, sat(fb, 1.8) * 1.2, final_at)
    ring = np.zeros_like(x)
    for fr in (880, 1320, 1760):
        d = 2.0
        mix_into(ring, sine(fr, d) * expdecay(d, 0.7) * 0.06, final_at)
    return reverb(x + ring, 0.28, 2.2, 2.2).mean(axis=0)[:int(dur * SR) + SR]


def glitch():
    dur = 0.5
    x = np.zeros(int(dur * SR))
    pos = 0
    while pos < len(x) - 400:
        seg = int(rng.uniform(0.012, 0.05) * SR)
        f = rng.choice([300, 520, 880, 1250, 2100])
        tone = square(float(f), seg / SR) * 0.35 if rng.random() < 0.5 else (noise(seg / SR) * 0.5)
        x[pos:pos + len(tone)] += tone[:len(x) - pos]
        pos += seg + int(rng.uniform(0, 0.02) * SR)
    x = bitcrush(x, 5, 3) * adsr(dur * 0.8, 0.002, 0.05, 0.9, 0.08, total=dur)
    return lp(hp(x, 150, 1), 4500)


def pillar_hit():
    dur = 0.4
    x = sat(sine(sweep(500, 120, dur, 0.4)) * expdecay(dur, 0.1) + lp(noise(dur), 4000) * expdecay(dur, 0.04) * 0.6, 2.0)
    return fade(x, 0.0005, 0.04)


def heartbeat():
    """Lub-dub at ~75 bpm interval handled in code; single pair here."""
    dur = 0.5
    out = np.zeros(int(dur * SR))
    for st, g in ((0.0, 1.0), (0.16, 0.7)):
        d = 0.18
        th = sine(sweep(95, 48, d, 0.5)) * expdecay(d, 0.06)
        mix_into(out, th * g, int(st * SR))
    return fade(lp(out, 400, 2), 0.001, 0.05)


SOUNDS = {}
