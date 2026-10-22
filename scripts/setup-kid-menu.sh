#!/usr/bin/env bash
#
# Build a kid-friendly menu for the child's Omarchy account.
#
# Adds three top-level sections to the Omarchy menu:
#   Learning   - school subjects and the learn-omarchy course
#   Games      - the puzzle and arcade games
#   Books      - the offline reference library
#
# Desktop entry IDs are resolved by matching the installed .desktop files, so
# this keeps working when a package renames its launcher.
#
# Usage:
#   sudo ./setup-kid-menu.sh edi
#
set -euo pipefail

exec 2>&1
echo "[kid-menu] START $(date)"
echo "[kid-menu] EUID=$EUID USER=$USER HOME=$HOME"

USER="${1:-edi}"
echo "[kid-menu] target user: $USER"
HOME_DIR="$(getent passwd "$USER" | cut -d: -f6 || true)"
echo "[kid-menu] HOME_DIR: $HOME_DIR"
EXT_DIR="$HOME_DIR/.config/omarchy/extensions"
EXT_FILE="$EXT_DIR/omarchy-menu.jsonc"
APP_DIRS=(/usr/share/applications /usr/local/share/applications "$HOME_DIR/.local/share/applications")
echo "[kid-menu] EXT_DIR: $EXT_DIR"
echo "[kid-menu] APP_DIRS: ${APP_DIRS[*]}"

if [[ $EUID -ne 0 ]] && [[ -z "${KID_MENU_AS_ROOT:-}" ]]; then
  echo "[kid-menu] not root (EUID=$EUID), attempting to elevate..." >&2
  if command -v pkexec >/dev/null 2>&1; then
    echo "[kid-menu] trying pkexec..." >&2
    exec pkexec env KID_MENU_AS_ROOT=1 "$0" "$@"
  elif command -v run0 >/dev/null 2>&1; then
    echo "[kid-menu] trying run0..." >&2
    exec run0 env KID_MENU_AS_ROOT=1 "$0" "$@"
  elif command -v machinectl >/dev/null 2>&1; then
    echo "[kid-menu] trying machinectl shell..." >&2
    exec machinectl shell .host /usr/bin/env KID_MENU_AS_ROOT=1 "$0" "$@"
  else
    echo "[kid-menu] NEEDS_ROOT" >&2
    echo "Needs root to write into another user's home:" >&2
    echo "  sudo $0 $USER" >&2
    exit 1
  fi
fi

if [[ -z "$HOME_DIR" ]]; then
  echo "[kid-menu] ERROR: could not resolve home for $USER" >&2
  exit 1
fi
if [[ ! -d "$HOME_DIR" ]]; then
  echo "[kid-menu] ERROR: No such user home: $HOME_DIR" >&2
  exit 1
fi

echo "[kid-menu] home exists"

# --- desktop entry resolution ------------------------------------------------

# resolve <desktop-id-suffix>... -> prints the first id that exists
resolve() {
  local wanted
  for wanted in "$@"; do
    local dir
    for dir in "${APP_DIRS[@]}"; do
      [[ -d "$dir" ]] || continue
      local candidate="$dir/$wanted.desktop"
      if [[ -f "$candidate" ]]; then
        printf '%s\n' "$wanted"
        return 0
      fi
    done
  done
  return 0
}

# find_by_name <name>... -> prints the id of a .desktop whose Name matches
find_by_name() {
  local wanted
  for wanted in "$@"; do
    local dir
    for dir in "${APP_DIRS[@]}"; do
      [[ -d "$dir" ]] || continue
      local file id
      shopt -s nullglob
      for file in "$dir"/*.desktop; do
        [[ -f "$file" ]] || continue
        id="$(basename "$file" .desktop)"
        if grep -qiE "^Name=($wanted)$" "$file" 2>/dev/null ||
           grep -qiE "^GenericName=($wanted)$" "$file" 2>/dev/null; then
          shopt -u nullglob
          printf '%s\n' "$id"
          return 0
        fi
      done
      shopt -u nullglob
    done
  done
  return 0
}

# --- row builder -------------------------------------------------------------

ROWS=()

# row <id> <icon> <label> <desktop-id> [description]
row() {
  local id="$1" icon="$2" label="$3" desktop="$4" description="${5:-}"
  [[ -n "$desktop" ]] || return 0
  local desc=""
  [[ -n "$description" ]] && desc=",\"description\":\"$description\""
  ROWS+=("    \"$id\": {\"icon\":\"$icon\",\"label\":\"$label\",\"action\":\"uwsm-app -- gtk-launch $desktop.desktop\"$desc}")
}

# Resolve everything first, so the menu only shows apps that really exist.
gcompris="$(resolve org.kde.gcompris || find_by_name 'GCompris')"
geogebra="$(resolve org.geogebra.Geogebra || find_by_name 'GeoGebra' 'GeoGebra Classic 5')"
kturtle="$(resolve org.kde.kturtle || find_by_name 'KTurtle')"
kgeography="$(resolve org.kde.kgeography || find_by_name 'KGeography')"
marble="$(resolve org.kde.marble || find_by_name 'Marble')"
stellarium="$(resolve org.stellarium || find_by_name 'Stellarium')"
kstars="$(resolve org.kde.kstars || find_by_name 'KStars')"
kwordquiz="$(resolve org.kde.kwordquiz || find_by_name 'KWordQuiz')"
khangman="$(resolve org.kde.khangman || find_by_name 'KHangMan')"
anki="$(resolve com.ichi2.anki || find_by_name 'Anki')"
learnomarchy="$(resolve learn-omarchy || find_by_name 'Learn Omarchy' 'Learn Omarchy Course')"

aisleriot="$(resolve org.gnome.AisleRiot || find_by_name 'AisleRiot' 'Solitaire')"
mines="$(resolve org.gnome.Mines || find_by_name 'GNOME Mines' 'Mines')"
sudoku="$(resolve org.gnome.Sudoku || find_by_name 'GNOME Sudoku' 'Sudoku')"
klotski="$(resolve org.gnome.Klotski || find_by_name 'GNOME Klotski' 'Klotski')"
taquin="$(resolve org.gnome.Taquin || find_by_name 'GNOME Taquin' 'Taquin')"
mahjongg="$(resolve org.gnome.Mahjongg || find_by_name 'GNOME Mahjongg' 'Mahjongg')"
lightsoff="$(resolve org.gnome.LightsOff || find_by_name 'Light Off' 'Lights Off')"
chess="$(resolve org.gnome.Chess || find_by_name 'Chess' 'GNOME Chess')"

supertux="$(resolve org.supertux2.SuperTux || find_by_name 'SuperTux')"
supertuxkart="$(resolve org.supertuxkart.SuperTuxKart || find_by_name 'SuperTuxKart')"
kmahjongg="$(resolve org.kde.kmahjongg || find_by_name 'KMahjongg')"
konquest="$(resolve org.kde.konquest || find_by_name 'Konquest')"
klickety="$(resolve org.kde.klickety || find_by_name 'Klickety')"
kolf="$(resolve org.kde.kolf || find_by_name 'Kolf')"
kbreakout="$(resolve org.kde.kbreakout || find_by_name 'KBreakout')"

krita="$(resolve org.kde.krita || find_by_name 'Krita')"
pinta="$(resolve org.xfce.Pinta || find_by_name 'Pinta')"
inkscape="$(resolve org.inkscape.Inkscape || find_by_name 'Inkscape')"
tuxpaint="$(resolve tuxpaint || find_by_name 'Tux Paint')"
audacity="$(resolve org.audacityteam.audacity || find_by_name 'Audacity')"

minetest="$(resolve minetest luanti || find_by_name 'Minetest' 'Luanti')"
turbowarp="$(resolve turbowarp-desktop || find_by_name 'TurboWarp')"

# --- learning ----------------------------------------------------------------

row "school"           "📚" "Learning"        ""                       "School subjects and practice"
row "school.omarchy"   "🎓" "Learn the desktop" "$learnomarchy"          "A guided course in Omarchy, with an arcade"
row "school.gcompris"  "🧠" "GCompris"          "$gcompris"              "Maths, logic, science, English and music activities"
row "school.geogebra"  "📐" "GeoGebra"          "$geogebra"              "Interactive maths and geometry"
row "school.kturtle"   "🐢" "KTurtle"           "$kturtle"               "Learn programming by drawing"
row "school.kgeography" "🗺" "KGeography"        "$kgeography"            "Geography quizzes with maps"
row "school.marble"    "🌍" "Marble"            "$marble"                "Explore a virtual globe"
row "school.stellarium" "🔭" "Stellarium"        "$stellarium"            "Planetarium and the night sky"
row "school.kstars"    "⭐" "KStars"            "$kstars"                "Star charts and the sky at night"
row "school.kwordquiz" "📖" "KWordQuiz"         "$kwordquiz"             "Vocabulary and spelling quizzes"
row "school.khangman"  "🔤" "KHangMan"          "$khangman"              "Hangman-style word game"
row "school.anki"      "🃏" "Anki"              "$anki"                  "Flashcards that learn what you forget"

# --- games -------------------------------------------------------------------

row "play"            "🎮" "Games"        ""             "Puzzles and arcade games"
row "play.supertux"   "🦖" "SuperTux"     "$supertux"    "Platform adventure"
row "play.supertuxkart" "🏎️" "SuperTuxKart" "$supertuxkart" "Kart racing"
row "play.minetest"   "🧱" "Minetest"     "$minetest"    "Build your own block world"
row "play.chess"      "♟️" "Chess"        "$chess"       "Play against the computer"
row "play.sudoku"     "🔢" "Sudoku"       "$sudoku"      "Number puzzle"
row "play.mines"      "💣" "Mines"        "$mines"       "Minesweeper"
row "play.klotski"    "🧩" "Klotski"      "$klotski"     "The classic sliding block puzzle"
row "play.taquin"     "🧱" "Taquin"       "$taquin"      "Sliding number puzzle"
row "play.mahjongg"   "🎴" "Mahjong"      "$mahjongg"    "Match the tiles"
row "play.kmahjongg"  "🀄" "KMahjongg"    "$kmahjongg"   "Match the tiles (KDE)"
row "play.aisleriot"  "🃏" "Solitaire"    "$aisleriot"   "Classic card solitaire"
row "play.lightsoff"  "💡" "Lights Out"   "$lightsoff"   "Turn off all the lights"
row "play.klickety"   "🔧" "Klickety"     "$klickety"    "Pipe puzzle"
row "play.kolf"       "⛳" "Kolf"         "$kolf"        "Mini golf"
row "play.kbreakout"  "🧱" "Breakout"     "$kbreakout"   "Break the bricks"
row "play.konquest"   "🗡️" "Konquest"     "$konquest"    "Strategy: conquer the world"

# --- creating ----------------------------------------------------------------

row "create"          "🎨" "Create"      ""             "Drawing, music and code"
row "create.tuxpaint" "🖍️" "Tux Paint"   "$tuxpaint"    "Simple drawing with lots of stamps"
row "create.krita"    "🖌️" "Krita"       "$krita"       "Professional painting"
row "create.pinta"    "🎨" "Pinta"       "$pinta"       "Simple paint program"
row "create.inkscape" "✏️" "Inkscape"    "$inkscape"    "Draw vector graphics"
row "create.audacity" "🎙️" "Audacity"    "$audacity"    "Record and edit sounds"
row "create.turbowarp" "🧩" "Scratch"     "$turbowarp"   "Make games and animations (works offline)"

# --- offline books ------------------------------------------------------------

row "books"           "📖" "Offline Books" "" "Wikipedia and textbooks, without internet"
row "books.all"       "📚" "All books"     "" ""
row "books.wikipedia" "🌐" "Wikipedia"    "" ""
row "books.textbooks" "🎓" "Textbooks"    "" ""

# The three book rows are not desktop entries; they run the offline launcher.
ROWS+=("    \"books.all\": {\"icon\":\"📚\",\"label\":\"All books\",\"action\":\"uwsm-app -- kiwix-offline\",\"description\":\"Every downloaded book\"}")
ROWS+=("    \"books.wikipedia\": {\"icon\":\"🌐\",\"label\":\"Wikipedia\",\"action\":\"uwsm-app -- kiwix-offline wikipedia\",\"description\":\"The whole encyclopedia, offline\"}")
ROWS+=("    \"books.textbooks\": {\"icon\":\"🎓\",\"label\":\"Textbooks\",\"action\":\"uwsm-app -- kiwix-offline wikibooks\",\"description\":\"Free textbooks for school projects\"}")

# --- write -------------------------------------------------------------------

echo "[kid-menu] writing to $EXT_FILE"
mkdir -p "$EXT_DIR"
echo "[kid-menu] created $EXT_DIR"
cp "$EXT_FILE" "$EXT_FILE.bak.$(date +%s)" 2>/dev/null || true
echo "[kid-menu] building menu with ${#ROWS[@]} rows"

{
  cat <<'HEADER'
// Kid-friendly menu for this account.
//
// Rows are merged into the stock Omarchy menu. Apps that are not installed
// are simply skipped when this file is generated, so the menu stays accurate.
//
// Regenerate with:  sudo ./setup-kid-menu.sh <user>
{
HEADER
  printf '%s\n' "${ROWS[@]}"
  echo "}"
} >"$EXT_FILE"
echo "[kid-menu] wrote $EXT_FILE"

chown -R "$USER:$USER" "$HOME_DIR/.config/omarchy"
echo "[kid-menu] chowned"

echo "Wrote $EXT_FILE with ${#ROWS[@]} rows."
echo
echo "Restart the shell for the new menu to appear:"
echo "  sudo -iu $USER systemctl --user restart omarchy-shell"
echo "[kid-menu] DONE"
