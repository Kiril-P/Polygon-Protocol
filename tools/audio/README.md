# Audio generator

All sound effects and the gameplay, boss and menu music are synthesised from code, so they can be tuned and re-rendered.

```bash
python3 -m venv .venv && .venv/bin/pip install numpy scipy pyloudnorm matplotlib
cd tools/audio
../../.venv/bin/python render_sfx.py      # -> assets/audio/sfx/*.wav
../../.venv/bin/python render_music.py    # -> assets/audio/music/*.ogg and assets/audio/menu/*.ogg  (needs ffmpeg)
../../.venv/bin/python plot.py out.png player_fire_0 level_up   # waveform/spectrogram sheet
```

* `synth.py` – oscillators, filters, reverb/echo, helpers
* `sfx.py` / `render_sfx.py` – every SFX and its target peak level
* `music.py` / `tracks.py` / `render_music.py` – instruments, sequencer and track data
  * 3 gameplay loops (`game_*.ogg`, ~-17 LUFS)
  * 3 boss themes, each 4 synchronized stems (`boss_<id>_{found,drums,arp,lead}.ogg`);
    `AudioManager` fades layers in per boss phase.
* `menu_tracks.py` – five calm menu tracks (`menu_*.ogg` -> `assets/audio/menu/`, ~-16 LUFS), shuffled as a playlist on the title screen

In-game levels, variants, cooldowns and voice limits live in `scripts/audio_manager.gd` (`SFX` table).
After re-rendering run `godot --headless --path . --import`.
