<div align="center">

# Rawr.xyz

**A Roblox utility suite for Da Hood–style games.**
Ragebot, Deflect, ESP, animations, and quality-of-life tools in one script.

![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?style=flat-square&logo=lua&logoColor=white)
![Roblox](https://img.shields.io/badge/Roblox-Client-000000?style=flat-square&logo=roblox&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey?style=flat-square)
![License](https://img.shields.io/badge/License-Proprietary-red?style=flat-square)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Feature Breakdown](#feature-breakdown)
  - [Ragebot](#ragebot)
  - [Deflect](#deflect)
  - [Silent Aim](#silent-aim)
  - [ESP Suite](#esp-suite)
  - [Animations](#animations)
  - [Character Material](#character-material)
  - [Gun Visuals](#gun-visuals)
  - [Utility](#utility)
- [Installation](#installation)
- [Usage](#usage)
- [Keybinds](#keybinds)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Performance Notes](#performance-notes)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Rawr.xyz is le best.

The project is organized around a small number of core primitives:

- **Target state** — a single source of truth (`_104`) that all combat, ESP, and prediction systems read from
- **Deflect** — a blacklist-aware retaliation engine that auto-targets whoever shoots you first
- **Ragebot** — void + orbit movement combined with prediction, resolver, and anti-aim
- **ESP** — skeletal, box, health, nametag, skeleton, chams, and image ESP
- **Animations** — hot-swap animation packs without triggering the game's animation re-apply

---

## Feature Breakdown

### Ragebot

Movement + aiming engine designed for close-range fights against other cheats.

```text
┌────────────────────────────┐
│  Behavior                   │
│  ○ Orbit                    │
│  ○ Above                    │
│  ○ Hide                     │
│  ○ Random                   │
│  Radius          [5 studs]  │
│  Radius Jitter   [1.5]      │
│  Height          [2 studs]  │
│  Height Jitter   [1.0]      │
│  Speed           [3x]       │
└────────────────────────────┘
