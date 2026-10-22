#!/usr/bin/env bash
#
# Install the offline learning + game suite for the child account on Omarchy.
#
#   sudo ./install-kid-apps.sh
#
# Stage 1: full system upgrade (so the package DB is not stale).
# Stage 2: learning suite + games from the official repos.
# Stage 3: AUR packages (built as the invoking user, installed with pkexec).
#
set -euo pipefail

REPO_PACKAGES=(
  # --- learn the desktop itself -------------------------------------------
  omarchy/learn-omarchy

  # --- core subjects ------------------------------------------------------
  gcompris-qt      # ~170 activities: maths, logic, science, English, music
  geogebra         # interactive maths / geometry
  kgeography       # geography quiz with maps
  marble           # virtual globe (offline Google Earth)
  stellarium       # planetarium
  kstars           # astronomy / star charts
  kturtle          # programming through turtle graphics

  # --- reading & vocabulary ----------------------------------------------
  kwordquiz        # vocabulary quizzes (many languages)
  khangman         # hangman-style spelling & vocabulary
  anki             # spaced-repetition flashcards

  # --- games --------------------------------------------------------------
  gnome-games      # solitaire, mines, sudoku, mahjongg, klotski, taquin...
  gnuchess         # chess
  supertux         # platformer
  supertuxkart     # racing
  kmahjongg        # mahjong
  konquest         # strategy (Risk-like)
  klickety         # pipe puzzle
  kolf             # mini golf
  kbreakout        # breakout

  # --- creative -----------------------------------------------------------
  krita            # painting
  pinta            # simple painting
  inkscape         # vector drawing
  audacity         # record and edit sounds

  # --- coding -------------------------------------------------------------
  python-pygame    # write your own games in Python

  # --- offline reference --------------------------------------------------
  kiwix-tools      # kiwix-serve: local offline web server for the ZIM files
  zim              # native desktop reader for ZIM files
)

AUR_PACKAGES=(
  minetest-git         # open Minecraft-like creative sandbox
  turbowarp-desktop-bin # offline Scratch-compatible coding environment
  tuxpaint             # kid-safe painting program
  tuxpaint-stamps      # extra stamp set for Tux Paint
)

LOG=/tmp/opencode/kid-apps-install.log
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "=== Stage 1/3: full system upgrade ==="
# Omarchy's pacman guard blocks a bare -Syu; OMARCHY_UPDATE_PACMAN=1 is the
# same switch omarchy-update-system-pkgs uses internally.
env LC_ALL=C OMARCHY_UPDATE_PACMAN=1 pacman -Syu --noconfirm \
  --overwrite '/usr/share/omarchy/*'

echo
echo "=== Stage 2/3: installing repo packages ==="
pacman -S --needed --noconfirm "${REPO_PACKAGES[@]}"

echo
echo "=== Stage 3/3: AUR packages ==="
BUILD_ROOT="${AUR_BUILD_ROOT:-$HOME/.cache/omarchy-kid-aur}"
mkdir -p "$BUILD_ROOT"

for pkg in "${AUR_PACKAGES[@]}"; do
  echo "--- fetching $pkg"
  yay --noconfirm --needed --sudo pkexec -S "$pkg" || {
    echo "!!! FAILED: $pkg" >&2
  }
done

echo
echo "=== Done ==="
pacman -Qq | grep -E '^(gcompris-qt|geogebra|kturtle|kgeography|marble|stellarium|kstars|kwordquiz|khangman|anki|gnome-games|gnuchess|supertux|supertuxkart|kmahjongg|konquest|klickety|kolf|kbreakout|krita|pinta|inkscape|audacity|python-pygame|kiwix-tools|zim|minetest-git|turbowarp-desktop-bin|tuxpaint|learn-omarchy)$' | sort
