#!/usr/bin/env bash
#
# Stage 4: the individual GNOME games (gnome-games is only a collection
# launcher) plus xboard for a graphical chess board.
#
set -euo pipefail

pacman -S --needed --noconfirm \
  aisleriot \
  gnome-mines \
  gnome-sudoku \
  gnome-klotski \
  gnome-taquin \
  gnome-mahjongg \
  lightsoff \
  xboard

echo
echo "=== Desktop entries now available ==="
ls /usr/share/applications/ | grep -iE 'aisle|mines|sudoku|klotski|taquin|mahjong|lightsoff|xboard|chess'
