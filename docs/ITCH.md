# itch.io page

Copy-paste material for https://kirilp.itch.io/polygon-protocol. Art is generated from the real captures in `docs/media` by
`python3 tools/itch/make_assets.py` (writes `docs/media/itch/`). The web build is made by `tools/web/build.sh` (see README).

## Art (all in `docs/media/itch/`)

The key art was made with an image model (no text in it, sources in `source/`: cover-1 star, cover-2 hexagon with lasers, cover-3
evolution burst, banner-1, social-1). `python3 tools/itch/compose.py` (Pillow, fetches Chakra Petch once) adds the title in
Chakra Petch Bold Italic and writes the finals.

| File | Size | Where it goes |
| --- | --- | --- |
| `cover.png` | 630 × 500 | Edit game → Cover image (cover-3: the circle bursting into a hexagon) |
| `banner.png` | 1600 × 400 | Theme → Banner |
| `social.png` | 1200 × 630 | Share-card / devlog header art |
| `evolution-strip.png` | 1280 × 260 | Page text, under "Evolve" (circle → hexagon) |
| `collage.png` | 1280 × 720 | Page text: menu, combat, boss, evolution select (real captures) |
| `bg-tile.png` | 512 × 512 | Theme → Background (seamless, repeat, fixed) |

Screenshots (1600 × 900, in `docs/media`): `combat.png`, `boss.png`, `evolution-select.png`, `protocols.png`, `menu.png`, in that order.
GIF: `hero.gif` (720 × 405).

## Theme (Edit theme button on the live page, owner view)

Applied on 2026-10-26:

- **Background** `#04071c`, **panel** `#0a1233`, **text** `#dbe6ff`, **links** `#2bd8ff`, **headings** `#ff43a0`, **button** `#2bd8ff`
- **Fonts** (Google Fonts, picked in the theme editor): body **Open Sans** (the game's own UI font), headings **Chakra Petch**
- **Banner** `banner.png`; **page background** `bg-tile.png`; no embed background image
- The cover, five screenshots, short description, tags and page text were also replaced (`build/itch_before.json`, git-ignored,
  has the previous form values).

## Page settings

- **Kind of project:** HTML (web build, `build/polygon-protocol-web.zip`), plus the Windows and macOS downloads
- **Embed:** "Embed in page", viewport **1280 × 720**, "Fullscreen button" on, "Mobile friendly" on (landscape),
  **SharedArrayBuffer support off** (the export is single-threaded). Leave auto-start off so audio starts after a click.
- **Classification:** Games → Shooter / Survival
- **Genre:** Shooter, Survival
- **Tags:** 2d, boss-battle, bullet-hell, fast-paced, neon, roguelite, singleplayer, survival
- **Input methods:** Keyboard, Mouse, Xbox controller, Touchscreen
- **Accessibility:** Configurable controls, Color-blind friendly, High-contrast, Reduced flashing
- **Average session:** 10–20 minutes
- **Content:** "No generative AI was used" is the current declaration. Keep it only if it is still true for code, art and audio.

## Short description (tagline)

Evolve into deadlier polygons. Dash through corrupted swarms. Break the bosses.

## Page text

Banner above. Then, in this order:

**Evolve. Dash. Survive.**

**POLYGON PROTOCOL** is a fast neon roguelite where your shape is your weapon. You start as a circle, gain an edge with every
evolution, and dash through corrupted swarms to survive escalating waves and four boss fights. Every dash is a weapon: you are
invulnerable while you move through enemies, and bosses can only be hurt by dashing into their pulsing hearts.

*(evolution-strip.png)*

Born in Mini Jam 202 (7th for Enjoyment out of 160 entries) and rebuilt into a full release.

### What's in it

- **11 enemy types**, including the shielded Aegis, a Splitter that bursts into fast shards, a Sniper whose aim locks when its
  beam flashes white, and a Mender that heals everything around it. A short intel card introduces each one the first time you meet it.
- **Upgrades that counter each threat**, plus named synergies when the right ones meet (Storm Front, Chain Reaction, Cascade and more).
- **Four bosses** (Fortress, Pulsar, Singularity, Prism), each with phases, a hexagon arena in Prism's case, and adaptive music
  that layers in as the fight escalates.
- **Protocols:** pick risk/reward modifiers before a run (Swarm, Hunters, Glass Core, Low Power, Vanguard, No Repairs, Elite Tide)
  for a higher score and shard multiplier.
- **Daily Protocol:** one seeded run a day, the same for everyone, with a streak counter and its own leaderboard.
- **Evolution Vault:** spend Quantum Shards on permanent upgrades and unlock starting shapes (Spark, Bastion, Comet, Hive).
- **Endless mode:** decline the first boss and keep surviving; the late waves lean on Tanks, Snipers, Aegis and Menders.
- **A short guided first run** that teaches move, dash, level up, shoot and combo, and can be skipped.
- **A death screen that explains itself:** what hit you, how fast you went down, and one thing to try next.

*(collage.png)*

### Controls

- **Keyboard and mouse:** WASD or mouse to move, Space or left click to dash (invulnerable while dashing), Esc to pause. Keys can be rebound.
- **Gamepad:** left stick or D-pad to move, RT / RB / X to dash, Start or B to pause. Controller vibration.
- **Phone and tablet:** drag on the left to move, hold the dash button to dash.

### Accessibility

Glow and screen-shake sliders, reduced-flash mode, colour-blind-safe palettes, a bigger HUD option, hit-stop toggle, full key rebinding.

### Online

The game has a daily and an all-time leaderboard (SilentWolf) and sends one anonymous record per run (upgrades taken, what killed
you, headline numbers) to help balance it. It has no name, player id or install id. Accessibility → Share anonymous run data turns
it off. No account, no cookies.

Built in Godot. Source: https://github.com/Kiril-P/Polygon-Protocol

### Credits

Design, code and direction: Kiril Petrovski. Menu music by Tokyo Music Walker and others via chosic.com. Particle, UI,
cursor, rune and rank packs and sound effects by Kenney (CC0). Open Sans, the in-game font, is under the SIL Open Font License.

**Can you survive the corruption?**

## Devlog post draft: "Polygon Protocol: a new look, a fourth boss, and a smaller download"

- A new itch page with proper art, plus four bosses with adaptive music (Prism's hexagon arena is new).
- The browser build is a lot lighter: the game data is 24 MB (it was 48 MB) and the engine compresses to about 7 MB on the wire.
- Quieter, less harsh sound effects across the board, with consistent loudness.
- Daily Protocol, Protocols and the Evolution Vault shape-tree are all in. Tell me which enemy you hate most.
