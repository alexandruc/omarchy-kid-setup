#!/usr/bin/env bash
#
# Install (or remove) the "omarchy-multiuser" SDDM greeter theme.
#
# Why this exists: the stock Omarchy SDDM theme is password-only. It hardcodes
# `property string currentUser: userModel.lastUser`, so after a logout the
# greeter can only ever log in as whoever logged in last -- there is no user
# chooser at all. This theme keeps the same look and adds one.
#
# The theme gets its own directory rather than patching
# /usr/share/sddm/themes/omarchy, because omarchy-refresh-sddm (and the
# plymouth theme refresh) rewrite that directory from the packaged defaults.
#
# Usage:
#   sudo ./install-sddm-multiuser-theme.sh
#   sudo ./install-sddm-multiuser-theme.sh --uninstall
#
set -euo pipefail

THEME_NAME="omarchy-multiuser"
BASE_THEME="omarchy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Overridable for testing.
SRC_DIR="${SDDM_THEME_SRC:-$SCRIPT_DIR/sddm-theme-omarchy-multiuser}"
DEST_DIR="${SDDM_THEME_DIR:-/usr/share/sddm/themes/$THEME_NAME}"
CONF_FILE="${SDDM_CONF_FILE:-/etc/sddm.conf.d/zz-multiuser.conf}"

# Image assets are shared with the Omarchy theme through symlinks so that
# `omarchy-refresh-sddm` keeps them in sync.
ASSETS=(logo.png bullet.png entry.png entry-failed.png lock.png lock-failed.png)

if [[ $EUID -ne 0 && $DEST_DIR == "/usr/share/sddm/themes/$THEME_NAME" ]]; then
  echo "This script writes to /usr and /etc, so it needs root:" >&2
  echo "  sudo $0 $*" >&2
  exit 1
fi

install_theme() {
  install -d -m 0755 "$DEST_DIR"

  install -m 0644 "$SRC_DIR/Main.qml" "$DEST_DIR/Main.qml"
  install -m 0644 "$SRC_DIR/metadata.desktop" "$DEST_DIR/metadata.desktop"
  install -m 0644 "$SRC_DIR/theme.conf" "$DEST_DIR/theme.conf"

  for asset in "${ASSETS[@]}"; do
    ln -sfn "../$BASE_THEME/$asset" "$DEST_DIR/$asset"
  done

  # sddm reads every file in /etc/sddm.conf.d in alphabetical order, so this
  # has to sort after 99-omarchy-login.conf to win.
  install -d -m 0755 "$(dirname "$CONF_FILE")"
  cat >"$CONF_FILE" <<EOF
[Theme]
Current=$THEME_NAME
EOF
  chmod 0644 "$CONF_FILE"

  echo "Installed theme: $DEST_DIR"
  echo "Config written:  $CONF_FILE"
  echo
  echo "Log out and pick the user at the greeter."
  echo "No sddm restart is needed: sddm reloads its config when the greeter starts."
}

uninstall_theme() {
  rm -f "$CONF_FILE"
  rm -rf "$DEST_DIR"
  echo "Removed $DEST_DIR and $CONF_FILE"
  echo "The Omarchy theme is used again."
}

case "${1:-}" in
  --uninstall) uninstall_theme ;;
  "") install_theme ;;
  *)
    echo "usage: $0 [--uninstall]" >&2
    exit 1
    ;;
esac
