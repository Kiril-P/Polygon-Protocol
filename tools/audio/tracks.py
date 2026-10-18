"""Track definitions: 3 gameplay loops + 3 layered boss themes."""
from music import *

# 16-step patterns --------------------------------------------------------
FOUR = {"kick": "X...X...X...X...", "clap": "....X.......X...", "hat": "x.x.x.x.x.x.x.x.", "open": "..X...X...X...X."}
FOUR_LIGHT = {"kick": "X...X...X...X...", "hat": "..x...x...x...x."}
BREAK = {"kick": "X.......X.......", "hat": "x...x...x...x..."}
HEAVY = {"kick": "X..x..X...x.X...", "snare": "....X..x....X...", "clap": "....X.......X...",
         "hat": "x.x.x.x.x.x.x.x.", "snare_kw": {"tone": 170, "body": 0.8, "tail": 0.18}}
HEAVY_FILL = dict(HEAVY, tom="............x.xX", tom_freq=110, snare="....X..x....X.xx")
DRIVE2 = {"kick": "X..X..X.X..X..X.", "snare": "....X.......X..x", "clap": "....X.......X...",
          "hat": "xxxxxxxxxxxxxxxx", "open": "..X...X...X...X."}
DOUBLE = {"kick": "X.x.X.x.X.x.X.x.", "snare": "..X...X...X...XX", "clap": "....X.......X...",
          "hat": "xxxxxxxxxxxxxxxx", "open": ".X...X...X...X.."}
FILL = {"kick": "X...X...X.X.X.X.", "snare": "........XXXXXXXX", "tom": "........xxXXxxXX", "tom_freq": 130}


def chord_stuff(key):
    return key


# ---------------------------------------------------------------- gameplay
def build_gameplay(spec):
    tr = Track(spec["bpm"], 32)
    prog = spec["prog"]  # 4 entries: dict(root, pad, arp)
    for bar in range(32):
        c = prog[bar % 4]
        sec = "A" if bar < 8 else "B" if bar < 16 else "C" if bar < 20 else "D"
        drum_on = (sec == "A" and bar >= 4) or sec in ("B", "D")
        bass_on = (sec == "A" and bar >= 4) or sec in ("B", "D")
        lead_on = sec in ("C", "D") or (sec == "B" and bar >= 12)
        full = sec in ("B", "D")
        # pad
        render_chords(tr, bar, c["pad"], gain=0.9 if sec != "C" else 1.2, cut=1600 if sec == "A" else 2400)
        # arp
        if sec != "C" or bar >= 16:
            arp_line(tr, bar, c["arp"], spec["arp_pat"][bar % 2], gain=0.55 if sec == "C" else 0.7,
                     cut=3800 if full else 2600, dur_steps=1.6)
        if drum_on:
            drums(tr, bar, FOUR if full else FOUR_LIGHT)
        elif sec == "C":
            drums(tr, bar, BREAK, vel=0.5) if bar >= 18 else None
        if bass_on:
            bass_line(tr, bar, c["root"], spec["bass_pat"], gain=0.95 if full else 0.8, cut=800 if full else 500)
        if lead_on:
            mel = spec["lead"][bar % 4]
            shift = 12 if (sec == "D" and bar >= 28) else 0
            lead_line(tr, bar, [(st, m + shift, ln) for st, m, ln in mel], gain=0.55 if sec != "D" else 0.6)
        if bar == 19:  # riser into the final drop
            tr.put("fx", riser(tr.bar, 400, 9000), bar, 0, 0.5)
            tr.put("fx", hat(True), bar, 15, 0.2)
        if bar in (8, 20):
            tr.put("fx", impact(1.2), bar, 0, 0.35)
    tr.duck(["pad", "arp", "lead"], 0.55, 0.15)
    finalize_stems(tr, {"arp": {"echo": (tr.step * 3, 0.45, 0.5)}, "lead": {"reverb": (0.28, 1.4, 3.0), "echo": (tr.step * 3, 0.35, 0.3)},
                        "pad": {"reverb": (0.2, 1.2, 3.0)}})
    tr.fold()
    mix = sum(tr.stems[k] * g for k, g in (("drums", 0.8), ("bass", 0.9), ("pad", 0.8), ("arp", 1.6), ("lead", 1.9), ("fx", 0.7)) if k in tr.stems)
    return mix


A = lambda a, b, c: dict(a=a)

GAMEPLAY = {
    "game_neon_drive": dict(
        bpm=124,
        prog=[dict(root=33, pad=[57, 60, 64], arp=[57, 60, 64, 69]),
              dict(root=29, pad=[53, 57, 60], arp=[57, 60, 65, 69]),
              dict(root=36, pad=[55, 60, 64], arp=[60, 64, 67, 72]),
              dict(root=31, pad=[55, 59, 62], arp=[59, 62, 67, 71])],
        arp_pat=[[0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 2, 4], [0, 2, 1, 3, 2, 3, 1, 2, 0, 2, 1, 3, 4, 3, 2, 1]],
        bass_pat=[(0, 0, 2), (2, 0, 1), (3, 12, 1), (4, 0, 2), (6, 0, 1), (7, 12, 1), (8, 0, 2), (10, 0, 1), (11, 12, 1), (12, 0, 2), (14, 7, 1), (15, 12, 1)],
        lead=[[(0, 69, 6), (6, 72, 2), (8, 76, 4), (12, 74, 2), (14, 72, 2)],
              [(0, 69, 4), (4, 72, 2), (6, 77, 6), (12, 76, 2), (14, 72, 2)],
              [(0, 67, 4), (4, 72, 4), (8, 76, 4), (12, 79, 4)],
              [(0, 74, 4), (4, 71, 4), (8, 74, 2), (10, 79, 6)]]),
    "game_vector_run": dict(
        bpm=132,
        prog=[dict(root=40, pad=[52, 55, 59], arp=[64, 67, 71, 76]),
              dict(root=36, pad=[52, 55, 60], arp=[64, 67, 72, 76]),
              dict(root=38, pad=[50, 54, 57], arp=[62, 66, 69, 74]),
              dict(root=35, pad=[50, 54, 59], arp=[62, 66, 71, 74])],
        arp_pat=[[0, 2, 1, 3, 0, 2, 1, 3, 0, 2, 1, 3, 2, 3, 4, 3], [0, 1, 2, 1, 3, 2, 1, 2, 0, 1, 2, 4, 3, 2, 1, 0]],
        bass_pat=[(0, 0, 1), (1, 0, 1), (2, 12, 1), (3, 0, 1), (4, 0, 1), (5, 0, 1), (6, 12, 1), (7, 0, 1), (8, 0, 1), (9, 0, 1), (10, 12, 1), (11, 0, 1), (12, 0, 1), (13, 7, 1), (14, 12, 1), (15, 10, 1)],
        lead=[[(0, 71, 6), (6, 76, 2), (8, 79, 4), (12, 78, 2), (14, 76, 2)],
              [(0, 72, 6), (6, 76, 2), (8, 79, 6), (14, 76, 2)],
              [(0, 74, 4), (4, 78, 4), (8, 81, 4), (12, 78, 4)],
              [(0, 71, 4), (4, 74, 4), (8, 78, 2), (10, 76, 6)]]),
    "game_glass_grid": dict(
        bpm=112,
        prog=[dict(root=38, pad=[50, 53, 57], arp=[62, 65, 69, 74]),
              dict(root=34, pad=[50, 53, 58], arp=[62, 65, 70, 74]),
              dict(root=41, pad=[48, 53, 57], arp=[60, 65, 69, 72]),
              dict(root=36, pad=[48, 52, 55], arp=[60, 64, 67, 72])],
        arp_pat=[[0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3], [0, 2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 2, 3, 2, 1, 0]],
        bass_pat=[(0, 0, 3), (3, 0, 1), (4, 0, 2), (6, 12, 1), (8, 0, 3), (11, 7, 1), (12, 0, 2), (14, 12, 1), (15, 10, 1)],
        lead=[[(0, 74, 8), (8, 77, 4), (12, 76, 4)], [(0, 74, 6), (6, 70, 2), (8, 77, 8)],
              [(0, 72, 6), (6, 77, 2), (8, 81, 8)], [(0, 79, 4), (4, 76, 4), (8, 72, 8)]]),
}


# ---------------------------------------------------------------- bosses
def build_boss(spec):
    tr = Track(spec["bpm"], 16, tail=4.0)
    prog = spec["prog"]
    for bar in range(16):
        c = prog[bar % 4]
        half = bar // 8
        last = (bar % 8 == 7)
        # foundation (bass + pad + choir + impacts)
        bass_line(tr, bar, c["root"], spec["bass_pat"][half], stem="found", gain=1.0, drive=spec.get("drive", 2.4), cut=spec.get("bass_cut", 1000))
        render_chords(tr, bar, c["pad"], stem="found", gain=0.8, cut=spec.get("pad_cut", 1500), a=0.08, r=0.3)
        if spec.get("choir") and bar % 2 == 0:
            tr.put("found", choir(c["choir"], tr.bar * 2 - 0.1), bar, 0, 0.95)
        if bar % 8 == 0:
            tr.put("found", impact(1.5), bar, 0, 0.42)
        if last:
            tr.put("found", riser(tr.bar, 300, 9500), bar, 0, 0.5)
        # drums
        pat = spec["drums"][half]
        if last:
            pat = FILL if spec.get("fills", True) else pat
        drums(tr, bar, pat, stem="drums", kick_kw=spec.get("kick_kw"))
        # arp
        arp_line(tr, bar, c["arp"], spec["arp_pat"][bar % 2], stem="arp", gain=1.5, dur_steps=spec.get("arp_dur", 1.5),
                 cut=spec.get("arp_cut", 4500), shape=spec.get("arp_shape", "saw"))
        # lead
        mel = spec["lead"][bar % 4]
        shift = 12 if half == 1 and spec.get("lead_up", True) else 0
        lead_line(tr, bar, [(st, m + shift, ln) for st, m, ln in mel], stem="lead", gain=1.7, wave=spec.get("lead_wave", "saw"), cut=spec.get("lead_cut", 3800))
    tr.duck(["found_pad_dummy"], 0)
    # sidechain the whole foundation lightly, arp/lead heavily
    tr.duck(["arp", "lead"], 0.5, 0.14)
    finalize_stems(tr, {"arp": {"echo": (tr.step * 3, 0.45, 0.5)}, "lead": {"reverb": (0.3, 1.8, 2.6), "echo": (tr.step * 3, 0.35, 0.3)},
                        "found": {"reverb": (0.12, 1.2, 3.0)}})
    tr.fold()
    return tr.stems


BOSSES = {
    "boss_fortress": dict(
        bpm=138, drive=3.0, bass_cut=850, pad_cut=1100, arp_shape="square", arp_cut=3200, lead_wave="square",
        prog=[dict(root=36, pad=[48, 51, 55], arp=[60, 63, 67, 72]),
              dict(root=36, pad=[48, 51, 55], arp=[60, 63, 67, 72]),
              dict(root=32, pad=[44, 48, 51], arp=[56, 60, 63, 68]),
              dict(root=34, pad=[46, 50, 53], arp=[58, 62, 65, 70])],
        bass_pat=[[(0, 0, 2), (2, 0, 1), (3, 0, 1), (4, 0, 2), (6, 12, 1), (7, 0, 1), (8, 0, 2), (10, 0, 1), (11, 0, 1), (12, 0, 2), (14, 3, 1), (15, 0, 1)],
                  [(0, 0, 1), (1, 0, 1), (2, 12, 1), (3, 0, 1), (4, 0, 1), (5, 0, 1), (6, 12, 1), (7, 0, 1), (8, 0, 1), (9, 0, 1), (10, 12, 1), (11, 0, 1), (12, 0, 1), (13, 0, 1), (14, 12, 1), (15, 3, 1)]],
        drums=[HEAVY, dict(HEAVY, hat="xxxxxxxxxxxxxxxx", kick="X.xxX.x.X.xxX.x.")],
        arp_pat=[[0, None, 1, None, 2, None, 1, None, 0, None, 1, None, 3, None, 2, None], [0, 0, None, 1, 2, 2, None, 3, 0, 0, None, 1, 3, 3, None, 2]],
        lead=[[(0, 72, 4), (4, 75, 2), (6, 79, 2), (8, 82, 6), (14, 79, 2)],
              [(0, 80, 4), (4, 79, 2), (6, 75, 2), (8, 77, 8)],
              [(0, 80, 4), (4, 77, 4), (8, 75, 4), (12, 72, 4)],
              [(0, 82, 4), (4, 79, 4), (8, 77, 2), (10, 75, 2), (12, 74, 4)]]),
    "boss_pulsar": dict(
        bpm=148, drive=2.2, bass_cut=1100, pad_cut=2200, arp_shape="saw", arp_cut=5200, lead_wave="saw", arp_dur=1.2,
        prog=[dict(root=29, pad=[53, 56, 60], arp=[65, 68, 72, 77]),
              dict(root=37, pad=[53, 56, 61], arp=[65, 68, 73, 77]),
              dict(root=32, pad=[51, 56, 60], arp=[63, 68, 72, 75]),
              dict(root=39, pad=[51, 55, 58], arp=[63, 67, 70, 75])],
        bass_pat=[[(i, 0 if i % 4 != 3 else 12, 1) for i in range(0, 16, 1) if i % 2 == 0] + [(i, 0, 1) for i in (1, 5, 9, 13)],
                  [(i, (0, 0, 12, 0)[i % 4], 1) for i in range(16)]],
        drums=[DRIVE2, dict(DRIVE2, snare="....X..x....X.x.", kick="X.xxX.xxX.xxX.xx")],
        arp_pat=[[0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 3, 4, 3], [4, 3, 2, 1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 2, 1]],
        lead=[[(0, 77, 6), (6, 80, 2), (8, 84, 8)], [(0, 85, 4), (4, 84, 4), (8, 80, 4), (12, 77, 4)],
              [(0, 80, 6), (6, 84, 2), (8, 87, 8)], [(0, 87, 4), (4, 85, 4), (8, 84, 4), (12, 80, 4)]]),
    "boss_singularity": dict(
        bpm=156, drive=3.2, bass_cut=950, pad_cut=1300, arp_shape="saw", arp_cut=4200, lead_wave="saw", choir=True, arp_dur=1.0, lead_cut=3200,
        prog=[dict(root=38, pad=[50, 53, 57], arp=[62, 65, 69, 74], choir=[50, 57, 62]),
              dict(root=34, pad=[46, 50, 53], arp=[58, 62, 65, 70], choir=[46, 53, 58]),
              dict(root=43, pad=[43, 46, 50], arp=[55, 58, 62, 67], choir=[43, 50, 55]),
              dict(root=33, pad=[45, 49, 52], arp=[57, 61, 64, 69], choir=[45, 52, 57])],
        bass_pat=[[(0, 0, 3), (3, 0, 1), (4, 0, 2), (6, 0, 1), (7, 12, 1), (8, 0, 3), (11, 0, 1), (12, 0, 2), (14, 0, 1), (15, 12, 1)],
                  [(i, 12 if i % 8 == 7 else 0, 1) for i in range(16)]],
        drums=[dict(HEAVY, kick="X.....X...x.X...", hat="x.x.x.x.x.x.x.xx"), DOUBLE],
        arp_pat=[[0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 4, 3], [0, 2, 4, 2, 1, 3, 5, 3, 2, 4, 6, 4, 3, 5, 7, 5]],
        lead=[[(0, 74, 8), (8, 77, 4), (12, 81, 4)], [(0, 82, 6), (6, 81, 2), (8, 77, 8)],
              [(0, 79, 6), (6, 82, 2), (8, 86, 8)], [(0, 85, 4), (4, 81, 4), (8, 76, 4), (12, 73, 4)]]),
}
