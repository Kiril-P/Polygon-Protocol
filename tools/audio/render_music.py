import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from tracks import *
from menu_tracks import MENU, build_menu
import pyloudnorm as pyln


def lufs(stereo):
    return pyln.Meter(SR).integrated_loudness(stereo.T)


def limit(x, ceiling=0.89):
    p = np.max(np.abs(x))
    return x * (ceiling / p) if p > ceiling else x

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "music")
MENU_OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "menu")
os.makedirs(OUT, exist_ok=True)
os.makedirs(MENU_OUT, exist_ok=True)
only = sys.argv[1:]

for name, spec in GAMEPLAY.items():
    if only and name not in only:
        continue
    t0 = time.time()
    mix = build_gameplay(spec)
    mix = sat(mix, 1.1)
    mix = limit(mix * 10 ** ((-17.0 - lufs(mix)) / 20.0))
    to_ogg(os.path.join(OUT, name + ".ogg"), mix)
    print(name, "%.1fs" % (len(mix[0]) / SR), "rendered in %.0fs" % (time.time() - t0), flush=True)

for name, spec in BOSSES.items():
    if only and name not in only:
        continue
    t0 = time.time()
    stems = build_boss(spec)
    total = sum(stems.values())
    scale = 10 ** ((-15.0 - lufs(sat(total, 1.1))) / 20.0)
    while np.max(np.abs(total * scale)) > 0.89:
        scale *= 0.97
    for sn, x in stems.items():
        to_ogg(os.path.join(OUT, f"{name}_{sn}.ogg"), x * scale)
    print(name, "%.1fs" % (len(total[0]) / SR), "stems:", list(stems), "in %.0fs" % (time.time() - t0), flush=True)

for name, spec in MENU.items():
    if only and name not in only:
        continue
    t0 = time.time()
    mix = build_menu(spec)
    mix = sat(mix, 1.05)
    mix = limit(mix * 10 ** ((-16.0 - lufs(mix)) / 20.0))
    to_ogg(os.path.join(MENU_OUT, name + ".ogg"), mix)
    print(name, "%.1fs" % (len(mix[0]) / SR), "rendered in %.0fs" % (time.time() - t0), flush=True)
