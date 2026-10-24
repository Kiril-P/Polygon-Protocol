#!/usr/bin/env python3
"""Summarise Polygon Protocol run telemetry.

  python3 tools/telemetry/report.py runs.jsonl [more.jsonl ...]
  python3 tools/telemetry/report.py --remote [--max 500]

Local input is the game's user://telemetry.jsonl (one JSON record per run).
--remote reads the SilentWolf board "telemetry_v1" with the public client key from
scripts/global_data.gd. SilentWolf returns a board's top scores first, so a remote read is
biased toward high-scoring runs; use it for build and upgrade trends, not for death rates.
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOARD = "telemetry_v1"


def load_local(paths):
    runs = []
    for p in paths:
        for line in Path(p).read_text().splitlines():
            line = line.strip()
            if line:
                runs.append(json.loads(line))
    return runs


def load_remote(maximum):
    src = (ROOT / "scripts" / "global_data.gd").read_text()
    key = re.search(r'"api_key":\s*"([^"]+)"', src).group(1)
    game = re.search(r'"game_id":\s*"([^"]+)"', src).group(1)
    url = f"https://api.silentwolf.com/get_scores/{game}?max={maximum}&ldboard_name={BOARD}&period_offset=0"
    req = urllib.request.Request(url, headers={"x-api-key": key, "x-sw-game-id": game})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"remote read failed (HTTP {e.code}). The board may not exist yet (it is created by the first posted "
                 "run) or SilentWolf wants extra headers; this path is untested. Use the local telemetry.jsonl instead.")
    runs = []
    for s in data.get("scores", []):
        meta = s.get("metadata") or {}
        if isinstance(meta, str):
            meta = json.loads(meta)
        if meta:
            runs.append(meta)
    return runs


def top(counter, n=8):
    total = sum(counter.values()) or 1
    return "\n".join(f"  {k or '(none)':<18} {v:>5}  {100 * v / total:4.0f}%" for k, v in counter.most_common(n))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--remote", action="store_true")
    ap.add_argument("--max", type=int, default=500)
    a = ap.parse_args()
    runs = load_remote(a.max) if a.remote else load_local(a.files)
    if not runs:
        sys.exit("no runs found")
    n = len(runs)
    print(f"{n} runs\n")
    print("Median run length: %d:%02d" % divmod(int(sorted(r.get("time", 0) for r in runs)[n // 2]), 60))
    print("\nWhat ends runs")
    print(top(Counter(r.get("killed_by", "") for r in runs)))
    print("\nMode / starting shape")
    print(top(Counter(f"{r.get('mode')}/{r.get('shape')}" for r in runs)))
    print("\nProtocols picked (standard runs)")
    proto = Counter(p for r in runs for p in r.get("protocols", []))
    print(top(proto))
    print("\nMost picked upgrades")
    picks = Counter(u for r in runs for _, u in r.get("picks", []))
    print(top(picks, 12))
    print("\nFirst upgrade taken")
    print(top(Counter(r["picks"][0][1] for r in runs if r.get("picks"))))
    died_early = sum(1 for r in runs if r.get("time", 0) < 60)
    print(f"\nDied in the first minute: {died_early} ({100 * died_early / n:.0f}%)")
    print(f"Dash empty at death: {sum(1 for r in runs if r.get('dash_empty'))} ({100 * sum(1 for r in runs if r.get('dash_empty')) / n:.0f}%)")
    fr = [r for r in runs if r.get("first_run")]
    if fr:
        print(f"\nFirst runs: {len(fr)}, median {sorted(r['time'] for r in fr)[len(fr) // 2]:.0f}s, "
              f"top killer {Counter(r.get('killed_by') for r in fr).most_common(1)[0][0]}")


if __name__ == "__main__":
    main()
