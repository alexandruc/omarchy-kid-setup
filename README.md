# Omarchy Kid Setup

Scripts to set up a kid-friendly, offline-capable environment on a clean [Omarchy](https://omarchy.org/) install.

## Features
- Creates/adds a child user account (`edi`) with appropriate permissions
- Installs educational apps (GCompris, GeoGebra, KGeography, Marble, Stellarium, KStars, KTurtle, KWordQuiz, KHangMan, Anki)
- Installs games (SuperTux, SuperTuxKart, Luanti, GNOME games, KDE games, etc.)
- Installs creative tools (TuxPaint, Krita, Pinta, Inkscape, Audacity)
- Installs coding tools (TurboWarp/Scratch offline, Python/Pygame)
- Sets up offline Wikipedia/textbooks via Kiwix (ZIM files)
- Creates a kid-friendly Omarchy menu

## Quick Start

On a clean Omarchy install:

```bash
git clone <repo> && cd omarchy-kid-setup
```

### 1. Create/add child user
```bash
sudo ./scripts/add-omarchy-user.sh
# or customize as needed
```

### 2. Install kid apps and games
```bash
sudo ./scripts/install-kid-apps.sh
```

### 3. Install extra GNOME games
```bash
sudo ./scripts/install-kid-games-extra.sh
```

### 4. Build and install AUR packages with patches
```bash
./scripts/build-aur-fixes.sh
```

### 5. Download offline books (requires internet)
```bash
sudo ./scripts/download-offline-books.sh
```

### 6. Wire up offline books
```bash
sudo ./scripts/install-offline-books.sh
```

### 7. Create kid-friendly menu
```bash
sudo ./scripts/setup-kid-menu.sh edi
```

### 8. Restart Omarchy shell
```bash
sudo -iu edi systemctl --user restart omarchy-shell
```

## Notes
- Leave machine in offline mode manually (no automatic firewall changes)
- ZIM files are large (~21GB by default). Use `--small` for a smaller set.
- The `edi` user has no wheel/sudo access by design.
