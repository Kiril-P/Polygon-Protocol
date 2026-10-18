import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from synth import *
import sfx

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)

# name -> (callable, target_peak_db)
items = {}
for i in range(4):
    items[f"player_fire_{i}"] = (lambda i=i: sfx.player_fire(i), -4)
for i in range(3):
    items[f"enemy_hit_{i}"] = (lambda i=i: sfx.enemy_hit(i), -4)
    items[f"enemy_death_{i}"] = (lambda i=i: sfx.enemy_death(i), -2)
items["enemy_death_big"] = (lambda: sfx.enemy_death(0, True), -1)
items.update({
    "enemy_fire": (sfx.enemy_fire, -6), "bullet_bounce": (sfx.bullet_bounce, -6),
    "bullet_explosion": (sfx.bullet_explosion, -2), "kamikaze_alert": (sfx.kamikaze_alert, -4),
    "player_hit": (sfx.player_hit, -1), "shield_break": (sfx.shield_break, -3),
    "shield_regen": (sfx.shield_regen, -5), "heal": (sfx.heal, -5),
    "dash_start": (sfx.dash_start, -4), "dash_loop": (sfx.dash_loop, -9), "dash_end": (sfx.dash_end, -6),
    "dash_empty": (sfx.dash_empty, -4), "dash_ready": (sfx.dash_ready, -6),
    "player_spawn": (sfx.player_spawn, -4), "level_up": (sfx.level_up, -3),
    "upgrade_select": (sfx.upgrade_select, -4), "combo_tick": (sfx.combo_tick, -8),
    "combo_break": (sfx.combo_break, -5), "ui_click": (sfx.ui_click, -6), "ui_hover": (sfx.ui_hover, -12),
    "pause": (sfx.pause, -5), "unpause": (sfx.unpause, -6), "game_over": (sfx.game_over, -2),
    "boss_spawn": (sfx.boss_spawn, -1), "boss_phase": (sfx.boss_phase, -1),
    "boss_warning": (sfx.boss_warning, -4), "boss_death": (sfx.boss_death, -1),
    "glitch": (sfx.glitch, -4), "pillar_hit": (sfx.pillar_hit, -3), "heartbeat": (sfx.heartbeat, -4),
})
report = []
for name, (fn, peak) in items.items():
    x = fn()
    x = np.nan_to_num(x)
    if name != "dash_loop":
        x = fade(x, 0.0, 0.03)
    x = peak_normalize(x, peak)
    write_wav(os.path.join(OUT, name + ".wav"), x)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    report.append((name, len(x) / SR, rms))
for r in report:
    print("%-20s %5.2fs  rms %6.1f dB" % r)
