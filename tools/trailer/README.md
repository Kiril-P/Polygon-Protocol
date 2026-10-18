# Trailer capture

`scenes/trailer.tscn` plays a scripted ~40 s take: title, early waves, a real level-up, synergies,
the Aegis / Splitter / Sniper / Mender enemies, a boss and an end card. A bot steers the player and
the run never touches the save file, settings or the online leaderboards.

```bash
tools/trailer/capture.sh                 # 1920x1080 @ 60 fps -> build/trailer/polygon-protocol-trailer.mp4
tools/trailer/capture.sh 46 1920x1080 60 "Out now on itch.io"   # length, size, fps, end-card line
```

Needs a real display (Godot's movie maker can't run `--headless`) and `ffmpeg`. Capture runs about
3x slower than real time; the intermediate AVI is large, so it lives in the git-ignored `build/`.
