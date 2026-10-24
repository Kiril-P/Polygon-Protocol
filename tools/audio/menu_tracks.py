"""Menu music: calm, lo-fi flavoured tracks (70-110 BPM) built from the same synth toolkit.

Soft electric-piano chords, a warm pad, a mellow bass, brushed drums and a
gentle bell-like lead. Each track is 64 bars: intro -> groove -> melody -> full -> outro.
"""
from music import *
from music import _cached


# ------------------------------------------------------------------ voices
def rhodes(m, dur):
    """Soft electric piano: sine body, quiet octave partial and a short bell 'tine'."""
    def make():
        f = midi(m)
        total = dur + 0.5
        t = t_axis(total)
        body = sine(f, total) + 0.42 * sine(f * 2.0, total) * np.exp(-t / 0.35) + 0.12 * sine(f * 3.0, total) * np.exp(-t / 0.18)
        tine = sine(f * 7.0, total) * np.exp(-t / 0.06) * 0.26 + sine(f * 4.0, total) * np.exp(-t / 0.12) * 0.12
        trem = 1 + 0.06 * np.sin(2 * np.pi * 4.6 * t)
        env = expdecay(total, max(dur * 0.9, 0.5))
        y = (body + tine) * env * trem
        y = lp(y, 4600, 2)
        return fade(y * 0.5, 0.004, 0.08)
    return _cached(("rhodes", m, round(dur, 3)), make)


def bell_lead(m, dur):
    """Gentle lead: triangle + sine with slow vibrato and a soft attack."""
    def make():
        total = dur + 0.5
        t = t_axis(total)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.2) / 0.4, 0, 1)
        f = midi(m) * vib
        sig = tri(f) * 0.6 + sine(f) * 0.4 + sine(f * 2.0) * 0.14 + sine(f * 3.0) * 0.05
        env = adsr(dur, 0.035, 0.18, 0.7, 0.45, total=total)
        return lp(sig * env, 4200, 2) * 0.6
    return _cached(("bell", m, round(dur, 3)), make)


def warm_pad(notes, dur):
    return pad_chord(notes, dur, cut=1500, voices=3, spread=0.01, a=0.9, r=1.2)


def soft_bass(m, dur):
    return bass_note(m, dur, drive=1.05, cut=380, sub=True)


# ------------------------------------------------------------------ drums
GROOVE = {"kick": "X.....x...X..x..", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}
GROOVE_LIGHT = {"kick": "X.......X.......", "hat": "..x...x...x...x."}
GROOVE_OPEN = {"kick": "X.....x...X.x...", "snare": "....X.......X..x", "hat": "x.xxx.x.x.xxx.x.", "open": "......X.......X."}
SOFT = {"tone": 210, "body": 0.45, "tail": 0.11}
KICK = {"punch": 0.55, "tail": 0.2}


def soft_drums(tr, bar, pattern, vel=0.5):
    p = dict(pattern)
    if "snare" in p:
        p["snare_kw"] = SOFT
    drums(tr, bar, p, vel=vel, kick_kw=KICK)


# ------------------------------------------------------------------ builder
def strum(tr, bar, step, notes, dur_steps, stem="keys", gain=1.0):
    for i, m in enumerate(notes):
        tr.put(stem, rhodes(m, dur_steps * tr.step), bar, step + i * 0.18, gain * (1.0 - 0.06 * i), pan=(i - len(notes) / 2) * 0.12)


def build_menu(spec):
    bars = spec.get("bars", 64)
    tr = Track(spec["bpm"], bars, tail=4.0)
    prog = spec["prog"]
    comp = spec["comp"]
    mel = spec["melody"]
    for bar in range(bars):
        c = prog[bar % 4]
        intro, outro = bar < 8, bar >= bars - 8
        groove = 8 <= bar < bars - 8
        full = 40 <= bar < bars - 8
        # pad
        tr.put("pad", warm_pad(c["pad"], tr.bar * 1.02), bar, 0, 0.85 if not full else 0.7)
        # keys: sparse in the intro and outro, full pattern otherwise
        pat = comp[0] if (intro or outro) else comp[1 if bar % 8 < 4 else 2]
        for step, ln in pat:
            strum(tr, bar, step, c["keys"], ln, gain=0.7 if (intro or outro) else 0.85)
        # bass
        if groove and bar >= 12:
            for step, off, ln in spec["bass"]:
                tr.put("bass", soft_bass(c["root"] + off, ln * tr.step * 0.95), bar, step, 0.8)
        # drums
        if groove and bar >= 12:
            soft_drums(tr, bar, GROOVE_LIGHT if bar < 16 else (GROOVE_OPEN if full and bar % 8 == 7 else GROOVE), vel=0.5)
        # melody: phrase A on 24-39, a varied phrase B (octave up on the repeat) on 40-55, hints in the outro
        phrase = None
        if 24 <= bar < 40:
            phrase = mel[0][bar % 4]
        elif 40 <= bar < bars - 8:
            phrase = mel[1][bar % 4]
            if bar >= 48:
                phrase = [(s, m + 12, ln) for s, m, ln in phrase] if spec.get("lift", True) else phrase
        elif outro and bar % 2 == 0:
            phrase = mel[0][bar % 4][:2]
        if phrase:
            for step, m, ln in phrase:
                tr.put("lead", bell_lead(m, ln * tr.step * 0.97), bar, step, 0.6, pan=0.05)
    tr.duck(["pad", "keys"], 0.18, 0.2)
    finalize_stems(tr, {"keys": {"echo": (tr.step * 3, 0.3, 0.22), "reverb": (0.28, 1.8, 2.8)},
                        "lead": {"echo": (tr.step * 3, 0.4, 0.3), "reverb": (0.3, 2.0, 2.6)},
                        "pad": {"reverb": (0.25, 1.6, 2.8)}})
    tr.fold()
    mix = sum(tr.stems[k] * g for k, g in (("drums", 0.75), ("bass", 0.95), ("pad", 0.9), ("keys", 1.7), ("lead", 1.5)) if k in tr.stems)
    return mix


# ------------------------------------------------------------------ track data
COMP_STEADY = [[(0, 12)], [(0, 7), (8, 7)], [(0, 6), (6, 4), (10, 6)]]
COMP_SWAY = [[(0, 16)], [(0, 6), (6, 4), (12, 4)], [(0, 4), (6, 6), (12, 4)]]
COMP_SPARSE = [[(0, 16)], [(0, 10), (10, 6)], [(0, 8), (8, 8)]]

BASS_WALK = [(0, 0, 4), (6, 0, 2), (8, 7, 4), (14, 0, 2)]
BASS_ROOT = [(0, 0, 6), (8, 0, 4), (12, 12, 2), (14, 7, 2)]
BASS_SLOW = [(0, 0, 8), (10, 7, 4), (14, 0, 2)]

MENU = {
    "menu_drift": dict(  # A minor
        bpm=92, comp=COMP_STEADY, bass=BASS_WALK,
        prog=[dict(root=45, keys=[57, 60, 64, 67], pad=[45, 52, 57, 60]),
              dict(root=41, keys=[53, 57, 60, 64], pad=[41, 48, 53, 57]),
              dict(root=48, keys=[60, 64, 67, 71], pad=[48, 55, 60, 64]),
              dict(root=43, keys=[55, 59, 62, 64], pad=[43, 50, 55, 59])],
        melody=[[[(0, 76, 4), (4, 74, 2), (6, 72, 2), (8, 69, 6)], [(0, 72, 4), (4, 69, 2), (6, 65, 2), (8, 67, 6)],
                 [(0, 67, 4), (4, 72, 4), (8, 76, 6), (14, 74, 2)], [(0, 71, 6), (6, 69, 2), (8, 67, 8)]],
                [[(0, 69, 4), (4, 72, 4), (8, 76, 4), (12, 79, 4)], [(0, 77, 6), (6, 76, 2), (8, 72, 8)],
                 [(0, 76, 4), (4, 79, 4), (8, 76, 4), (12, 74, 4)], [(0, 74, 8), (8, 71, 4), (12, 67, 4)]]]),
    "menu_afterglow": dict(  # F major
        bpm=108, comp=COMP_SWAY, bass=BASS_ROOT,
        prog=[dict(root=41, keys=[53, 57, 60, 64], pad=[41, 48, 53, 57]),
              dict(root=38, keys=[50, 53, 57, 60], pad=[38, 45, 50, 53]),
              dict(root=34, keys=[58, 62, 65, 69], pad=[34, 41, 46, 50]),
              dict(root=36, keys=[55, 60, 64, 67], pad=[36, 43, 48, 52])],
        melody=[[[(0, 72, 4), (4, 74, 2), (6, 77, 6), (12, 76, 4)], [(0, 74, 6), (6, 72, 2), (8, 69, 8)],
                 [(0, 70, 4), (4, 74, 4), (8, 77, 4), (12, 74, 4)], [(0, 72, 8), (8, 67, 4), (12, 69, 4)]],
                [[(0, 77, 6), (6, 76, 2), (8, 72, 8)], [(0, 74, 4), (4, 77, 4), (8, 81, 6), (14, 77, 2)],
                 [(0, 77, 4), (4, 74, 4), (8, 70, 8)], [(0, 76, 6), (6, 72, 2), (8, 67, 8)]]]),
    "menu_paper_lanterns": dict(  # D dorian-ish
        bpm=98, comp=COMP_STEADY, bass=BASS_WALK,
        prog=[dict(root=38, keys=[53, 57, 60, 64], pad=[38, 45, 50, 53]),
              dict(root=34, keys=[53, 58, 62, 65], pad=[34, 41, 46, 50]),
              dict(root=43, keys=[53, 58, 62, 67], pad=[43, 50, 55, 58]),
              dict(root=45, keys=[55, 61, 64, 67], pad=[45, 52, 57, 61])],
        melody=[[[(0, 69, 2), (2, 74, 4), (6, 77, 2), (8, 76, 8)], [(0, 74, 4), (4, 70, 4), (8, 74, 2), (10, 77, 6)],
                 [(0, 70, 4), (4, 74, 4), (8, 79, 4), (12, 77, 4)], [(0, 73, 4), (4, 76, 4), (8, 81, 6), (14, 76, 2)]],
                [[(0, 77, 4), (4, 81, 4), (8, 77, 4), (12, 76, 4)], [(0, 74, 6), (6, 70, 2), (8, 72, 8)],
                 [(0, 74, 4), (4, 70, 4), (8, 67, 8)], [(0, 76, 6), (6, 73, 2), (8, 69, 8)]]]),
    "menu_low_tide": dict(  # G minor
        bpm=84, comp=COMP_SWAY, bass=BASS_SLOW,
        prog=[dict(root=43, keys=[55, 58, 62, 65], pad=[43, 50, 55, 58]),
              dict(root=39, keys=[51, 55, 58, 62], pad=[39, 46, 51, 55]),
              dict(root=34, keys=[58, 62, 65, 69], pad=[34, 41, 46, 50]),
              dict(root=41, keys=[53, 57, 60, 63], pad=[41, 48, 53, 57])],
        melody=[[[(0, 74, 4), (4, 77, 4), (8, 79, 6), (14, 77, 2)], [(0, 75, 6), (6, 74, 2), (8, 70, 8)],
                 [(0, 74, 4), (4, 77, 4), (8, 81, 4), (12, 77, 4)], [(0, 72, 4), (4, 75, 2), (6, 74, 2), (8, 72, 8)]],
                [[(0, 79, 6), (6, 77, 2), (8, 74, 8)], [(0, 77, 4), (4, 75, 4), (8, 74, 8)],
                 [(0, 77, 6), (6, 74, 2), (8, 69, 8)], [(0, 75, 4), (4, 72, 4), (8, 70, 8)]]]),
    "menu_slow_orbit": dict(  # D minor, sparse
        bpm=78, comp=COMP_SPARSE, bass=BASS_SLOW, lift=False,
        prog=[dict(root=38, keys=[53, 57, 60, 64], pad=[38, 45, 50, 53]),
              dict(root=34, keys=[58, 62, 65, 69], pad=[34, 41, 46, 50]),
              dict(root=43, keys=[55, 58, 62, 65], pad=[43, 50, 55, 58]),
              dict(root=45, keys=[57, 60, 64, 67], pad=[45, 52, 57, 60])],
        melody=[[[(0, 81, 10), (12, 77, 4)], [(0, 77, 8), (8, 74, 8)], [(0, 74, 6), (6, 70, 2), (8, 72, 8)], [(0, 76, 6), (6, 74, 2), (8, 69, 8)]],
                [[(0, 77, 6), (6, 81, 2), (8, 79, 8)], [(0, 77, 4), (4, 74, 4), (8, 70, 8)], [(0, 74, 8), (8, 77, 4), (12, 72, 4)], [(0, 76, 8), (8, 73, 8)]]]),
}
