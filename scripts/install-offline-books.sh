#!/usr/bin/env bash
#
# Wire up the offline reference books:
#   - the kiwix-offline launcher
#   - a systemd user service that serves the ZIM files on 127.0.0.1:8080
#   - desktop entries so the child can open the books from the app menu
#   - the user service enabled for every local account
#
# Usage:
#   sudo ./install-offline-books.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIM_DIR="${ZIM_DIR:-/usr/share/kiwix/zim}"
BIN_DEST="/usr/local/bin/kiwix-offline"
UNIT_DEST="/etc/systemd/user/kiwix-offline.service"
APP_DIR="/usr/share/applications"

if [[ $EUID -ne 0 ]]; then
  echo "This script writes to /usr and /etc, so it needs root:" >&2
  echo "  sudo $0" >&2
  exit 1
fi

echo "==> Installing launcher"
install -Dm755 "$SCRIPT_DIR/kiwix-offline" "$BIN_DEST"

echo "==> Installing systemd user service"
install -Dm644 "$SCRIPT_DIR/kiwix-offline.service" "$UNIT_DEST"

echo "==> Installing desktop entries"
install -d -m 0755 "$APP_DIR"

cat >"$APP_DIR/Offline Books.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Offline Books
GenericName=Offline reference library
Comment=Browse Wikipedia and textbooks offline
Icon=accessories-dictionary
Terminal=false
Categories=Education;Network;
Exec=$BIN_DEST
StartupNotify=true
EOF

cat >"$APP_DIR/Offline Wikipedia.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Offline Wikipedia
GenericName=Offline encyclopedia
Comment=Search Wikipedia without an internet connection
Icon=accessories-dictionary
Terminal=false
Categories=Education;Network;
Exec=$BIN_DEST wikipedia
StartupNotify=true
EOF

# A book picker, one entry per installed ZIM file.
book_count=0
for zim in "$ZIM_DIR"/*.zim; do
  [[ -e "$zim" ]] || continue
  file="$(basename "$zim")"
  # Turn wikipedia_en_astronomy_nopic_2026-08.zim into "Astronomy"
  label="$(printf '%s' "$file" |
    sed -E 's/_[0-9]{4}-[0-9]{2}\.zim$//; s/\.zim$//' |
    tr '_' ' ' | sed -E 's/^(.)/\u\1/')"
  cat >"$APP_DIR/Offline Book - $label.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Offline Book - $label
Comment=Open $label offline
Icon=accessories-dictionary
Terminal=false
Categories=Education;Network;
Exec=$BIN_DEST "$file"
StartupNotify=true
EOF
  book_count=$((book_count + 1))
done

update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo "==> Enabling the user service for every local account"
while read -r user; do
  [[ -n "$user" ]] || continue
  home="$(getent passwd "$user" | cut -d: -f6)"
  [[ -d "$home" ]] || continue
  echo "    - $user"
  install -d -o "$user" -m 0700 "$home/.config/systemd/user"
  su - "$user" -c "systemctl --user daemon-reload" >/dev/null 2>&1 || true
  su - "$user" -c "systemctl --user enable --now kiwix-offline.service" >/dev/null 2>&1 || \
    echo "      (could not start now -- it will start at the next login)"
done < <(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

echo
echo "Installed:"
echo "  launcher : $BIN_DEST"
echo "  service  : $UNIT_DEST"
echo "  books    : $book_count"
