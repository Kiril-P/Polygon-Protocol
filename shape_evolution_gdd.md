# Shape Evolution - Game Design Document

**Game Title:** Shape Evolution  
**Genre:** Top-Down Bullet Heaven / Survivor-like  
**Platform:** PC (Godot Engine)  
**Target:** Mini Jam 202  
**Theme:** Power-up  
**Limitation:** Ridiculously Overpowered  

---

## High Concept

A geometric bullet heaven where you evolve from a simple circle into increasingly complex shapes. Each edge you gain adds a new bullet to your arsenal, turning you from a desperate dasher into a screen-filling maelstrom of projectiles.

---

## Core Gameplay Loop

1. **Survive** - Dodge incoming enemies while collecting XP
2. **Level Up** - Gain XP from kills, choose upgrades each level
3. **Evolve** - Every 5 levels, gain an edge and unlock new bullets
4. **Dominate** - Become absurdly powerful with synergistic upgrades
5. **Die & Repeat** - Spend Shards on meta-progression, start stronger

---

## Player Mechanics

### Shape Evolution System

**Automatic progression every 5 levels:**

| Level | Shape | Edges | Bullets | Gameplay Feel |
|-------|-------|-------|---------|---------------|
| 1 | Circle | 0 | 0 | Dash-only, high risk melee combat |
| 5 | Triangle | 3 | 3 | First ranged attack, still mobile |
| 10 | Square | 4 | 4 | Balanced offense/defense |
| 15 | Pentagon | 5 | 5 | Power spike, screen coverage improving |
| 20 | Hexagon | 6 | 6 | Strong mid-game, multiple targets |
| 25 | Heptagon | 7 | 7 | Getting ridiculous |
| 30 | Octagon | 8 | 8 | Late game monster |
| 35+ | Continue adding edges | 9-16+ | 9-16+ | Absolute chaos |

**Special Evolution Branches (Optional):**
- Level 20: Hexagon OR 6-Pointed Star (different firing pattern)
- Level 30: Octagon OR 4-Pointed Star+ (fewer bullets, massive damage)

### Movement
- **WASD** - 8-directional movement
- **Base Speed:** 300 units/sec
- **Hitbox:** Grows slightly with shape size
- **Auto-rotation:** Shape constantly rotates, sweeping bullets around

### Dash Mechanic
- **Space Bar** - Dash in movement direction
- **Starting Charges:** 1 charge
- **Cooldown:** 1 second per charge
- **Duration:** 0.2 seconds
- **Speed:** 800 units/sec
- **Effects:** 
  - Circle only: Kills enemies on contact
  - All shapes: Deals 2x bullet damage to enemies hit
  - Upgradeable: Can leave trails, grant invincibility, spawn clones

### Shooting Mechanic
- **Unlocked at:** Level 5 (Triangle)
- **Fire Pattern:** One bullet per edge, equally spaced around shape
- **Auto-fire:** Continuous shooting while shape rotates
- **Fire Rate:** 0.15 seconds between volleys (adjustable)
- **Bullet Behavior:** 
  - Fires outward from each edge
  - Direction determined by current rotation angle
  - Base damage: 10
  - Base speed: 400 units/sec

---

## Progression Systems

### Per-Run Progression (Temporary)

**Level up every ~100 XP (scales 15% per level)**

Each level grants choice of 3 random upgrades from pool:

#### Early Upgrades (Level 1-10)
- **+10% Movement Speed** - Move faster
- **+20% Bullet Damage** - Hit harder
- **+1 Dash Charge** - More mobility
- **-15% Dash Cooldown** - Dash more often
- **Bullets Pierce +1** - Hit multiple enemies
- **+10% Bullet Speed** - Bullets travel faster
- **+10% Fire Rate** - Shoot more often
- **Larger XP Magnet** - Pull XP from further away

#### Mid Upgrades (Level 11-25)
- **Bouncing Bullets** - Bullets bounce off screen edges
- **Dash Trail** - Leave damaging trail while dashing
- **Explosive Bullets** - Every 5th bullet explodes (50% AoE damage)
- **Homing Bullets** - Bullets curve toward enemies
- **+30% XP Pickup Range** - Bigger magnet, slight pull toward XP
- **-10% Hitbox Size** - Easier dodging
- **+50% Dash Damage** - Dash becomes deadly
- **Bullet Acceleration** - Bullets speed up over distance

#### Late Upgrades (Level 26+)
- **Splitting Bullets** - Bullets split into 2 on hit (60% damage each)
- **Dash Clone** - Dash creates shooting clone for 3 seconds
- **Orbital Bullets** - Bullets orbit you briefly before firing
- **Chain Lightning** - Bullets chain to 3 nearby enemies (70% damage)
- **Black Hole** - Kill 3 enemies in 1 sec spawns damage vortex
- **Rotation Frenzy** - Rotate faster when enemies are close
- **Death Explosion** - Enemies explode on death, damaging others
- **Bullet Duplication** - 20% chance bullets duplicate on fire

### Meta Progression (Permanent)

**Spend Shards earned from runs**

| Upgrade | Cost | Effect |
|---------|------|--------|
| **Head Start I** | 500 | Start as Triangle (Level 5) |
| **Head Start II** | 2000 | Start as Square (Level 10) |
| **Head Start III** | 5000 | Start as Pentagon (Level 15) |
| **Dash Mastery** | 300 | +1 permanent dash charge |
| **Sharp Edges I-V** | 400 each | +5% damage per edge (stacking) |
| **Quantum Shape** | 800 | 10% chance for +1 temporary edge (5 sec) |
| **XP Magnet** | 250 | +20% permanent XP range |
| **Second Wind** | 1000 | Survive lethal hit once per run |
| **Efficient Leveling** | 600 | XP requirements scale 10% instead of 15% |
| **Starting Boost** | 400 | Begin each run at Level 3 |
| **Shard Multiplier** | 1500 | Earn 25% more shards per run |

**Shard Earning:**
- 1 Shard per enemy killed
- 10 Shards per minute survived
- Bonus shards for reaching level milestones

---

## Enemy Design

### Enemy Types

#### Basic Chaser
- **Health:** 30
- **Speed:** 200 units/sec
- **Behavior:** Moves directly toward player
- **Spawn Rate:** High
- **XP:** 10

#### Shooter
- **Health:** 20
- **Speed:** 150 units/sec
- **Behavior:** Keeps distance, fires bullets at player
- **Spawn Rate:** Medium
- **XP:** 15

#### Tank
- **Health:** 100
- **Speed:** 100 units/sec
- **Behavior:** Slow chase, high HP
- **Spawn Rate:** Low
- **XP:** 30

#### Splitter
- **Health:** 40
- **Speed:** 180 units/sec
- **Behavior:** Splits into 2 smaller enemies on death
- **Spawn Rate:** Medium
- **XP:** 20 (10 per split)

#### Speedster
- **Health:** 15
- **Speed:** 400 units/sec
- **Behavior:** Fast, erratic movement
- **Spawn Rate:** Medium
- **XP:** 12

### Spawn System
- Enemies spawn at edges of screen
- Spawn rate increases over time
- Enemy type mix changes as game progresses:
  - 0-5 min: Mostly Chasers
  - 5-10 min: Add Shooters and Speedsters
  - 10-15 min: Add Tanks and Splitters
  - 15+ min: All types, high density

---

## Visual Design

### Art Style
- **Minimalist geometric shapes** - Clean, simple polygons
- **Vibrant neon colors** - High contrast against dark background
- **Heavy post-processing:**
  - Bloom/glow on all shapes
  - Screen shake on kills/level ups
  - Chromatic aberration on dash
  - Particle trails on everything
- **Color Scheme:**
  - Player: Cyan/White (evolves with upgrades)
  - Enemies: Red/Orange spectrum
  - Bullets: Bright cyan/yellow
  - XP: Gained directly upon enemy destruction
  - Background: Dark purple/blue gradient

### Particle Effects
- **Player dash:** Motion blur trail
- **Bullet fire:** Small spark at spawn
- **Enemy death:** Explosion of colored particles
- **Level up:** Screen-wide pulse, particle burst
- **Shape evolution:** Massive particle explosion, screen freeze frame
- **XP collection:** Streak effect toward player

### UI Design
- **Minimal HUD:**
  - Top left: Level, XP bar
  - Top right: Dash charges
  - Center screen: Upgrade selection on level up
- **Upgrade Cards:** 
  - Large, readable
  - Show icon + name + description
  - Highlight synergies with existing upgrades

---

## Audio Design

### Music
- **Main Theme:** High-energy electronic/synthwave
- **Intensity Scaling:** Music layers/speeds up as enemies increase
- **Boss/Milestone:** Music shift at major level milestones

### Sound Effects
- **Dash:** Whoosh with reverb
- **Bullet Fire:** Rapid pew sounds (pitched based on shape)
- **Enemy Hit:** Satisfying impact
- **Enemy Death:** Pop/explosion
- **Level Up:** Triumphant chime
- **Shape Evolution:** Massive, resonant transformation sound
- **XP Pickup:** Gentle collect sound

---

## Technical Implementation

### File Structure
```
/game_root
  /scenes
	- main.tscn (Main game scene)
	- player.tscn
	- bullet.tscn
	- enemy.tscn (base)
	- ui_upgrade_selection.tscn
	- ui_meta_shop.tscn
  /scripts
	- player.gd
	- bullet.gd
	- enemy.gd
	- spawner.gd
	- upgrade_manager.gd
	- meta_progression.gd
  /assets
	/shaders
	/particles
	/audio
```

### Key Systems

**Upgrade System:**
- Upgrade pool stored in UpgradeManager singleton
- Weighted random selection based on level
- Avoid duplicates in same selection
- Track active upgrades for synergy detection

**Enemy Spawning:**
- SpawnerManager controls all enemy spawning
- Difficulty curve based on time + player level
- Spawn positions calculated around screen edges
- Enemy type selection from weighted pool

**Meta Progression:**
- Save/load system for shard count and unlocks
- JSON file storage for persistence
- Shop UI for spending shards between runs

---

## Scope & Timeline (For Jam)

### Must Have (Core Loop)
- ✅ Player movement + dash
- ✅ Shape evolution (at least Circle → Triangle → Square → Pentagon)
- ✅ Basic shooting
- ✅ 2-3 enemy types (Chaser, Shooter, Tank)
- ✅ XP and level up system
- ✅ 10-15 upgrade options
- ✅ Basic spawning system
- ✅ Polish: particles, screen shake, juice

### Should Have (Enhanced Experience)
- ✅ Full shape progression to Octagon+
- ✅ 5 enemy types
- ✅ 20+ upgrade options with synergies
- ✅ Meta progression system (basic)
- ✅ Better visual effects and post-processing
- ✅ Sound effects and music

### Could Have (If Time Permits)
- ⚠️ Boss enemies at milestones
- ⚠️ Special evolution branches (Star variants)
- ⚠️ Achievement system
- ⚠️ Leaderboards/stats tracking
- ⚠️ Multiple game modes

### Won't Have (Post-Jam)
- ❌ Multiple characters
- ❌ Multiplayer
- ❌ Procedural levels
- ❌ Story/campaign mode

---

## Balancing Guidelines

### Power Curve
- **Early (Levels 1-10):** Player feels weak, dash-focused, survival challenge
- **Mid (Levels 11-20):** Power spike, first taste of "overpowered"
- **Late (Levels 21-30):** Absurd power, screen-filling chaos
- **End (Levels 31+):** Literal bullet hell that YOU create

### Enemy Scaling
- Enemy HP scales: Base × (1 + 0.1 × minutes_survived)
- Enemy count scales: Base × (1 + 0.15 × minutes_survived)
- Enemy speed scales slowly: Base × (1 + 0.05 × minutes_survived)

### XP Scaling
- XP per level: 100 × (1.15 ^ level)
- XP from enemies: Scales with enemy HP
- Goal: Level every 20-30 seconds early, 45-60 seconds late

---

## Win Condition & Game End

**No traditional win condition** - Survive as long as possible

**Run Ends When:**
- Player health reaches 0
- Player chooses to quit

**Post-Run Screen:**
- Time survived
- Enemies killed
- Max level reached
- Shards earned
- Return to meta shop

---

## Unique Selling Points

1. **Shape-Based Power Fantasy** - Literally watch yourself evolve into complexity
2. **Geometric Elegance** - Beautiful minimalist visuals with maximum impact
3. **Synergy Hunting** - Discovering broken upgrade combinations
4. **The "Circle Challenge"** - Early game is melee-only, high risk/reward
5. **Visual Spectacle** - Late game is complete sensory overload (the good kind)

---

## Design Pillars

1. **ESCALATION** - Always getting more powerful, more chaotic, MORE
2. **CLARITY** - Despite chaos, player always knows what's happening
3. **SATISFACTION** - Every action feels impactful and rewarding
4. **ELEGANCE** - Simple shapes, complex emergent gameplay

---

## Post-Jam Roadmap

**Version 1.1 - Content Update**
- 3 new enemy types
- Boss enemies every 10 levels
- 15 new upgrades
- 2 new shape evolution branches

**Version 1.2 - Meta Update**
- Expanded meta progression tree
- Achievement system
- Daily challenges
- Statistics tracking

**Version 1.3 - Polish Update**
- Improved visual effects
- Better balancing
- Quality of life improvements
- Performance optimizations

---

## Notes & Design Philosophy

**"Ridiculously Overpowered" Implementation:**
- Never nerf the player - only escalate enemy difficulty
- Upgrade synergies should create genuinely broken combinations
- Late game should be visually incomprehensible (in a good way)
- Players should feel like unstoppable gods... until they're not

**Accessibility:**
- Colorblind modes (adjust neon colors)
- Adjustable screen shake
- Particle density options
- Pause functionality

**Juice & Polish:**
- Every action needs feedback (visual, audio, haptic if possible)
- Screen shake is your friend
- Particle effects on EVERYTHING
- Sound design as important as visual design

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Created For:** Mini Jam 202
