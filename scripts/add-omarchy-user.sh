#!/usr/bin/env bash
#
# add-omarchy-user.sh — add a second (non-admin) Omarchy account.
#
# Omarchy ships no `omarchy add user` command; it is built around a single
# user. A second account still works, because:
#
#   * /etc/skel already carries the whole Omarchy + Hyprland user config set
#     (hypr/*.lua, omarchy/shell.json, the menu extension, terminal configs),
#     and `useradd -m` copies it into the new home.
#   * The per-user Omarchy setup that the installer normally runs for the
#     owner (theme, keyring, xdg dirs, app launchers) is seeded here.
#
# The new account is deliberately NOT added to `wheel`, so it has no sudo and
# no root access. Device access (audio/video/input) still works: systemd-logind
# hands out seat ACLs at login, which is why the owner's own account only
# carries `wheel` too.
#
# Usage:  sudo ./add-omarchy-user.sh <username> [full-name]
#
# Environment:
#   OMARCHY_THEME   theme to apply (default: tokyo-night)

set -euo pipefail

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
THEME="${OMARCHY_THEME:-tokyo-night}"

usage() {
  cat <<EOF
Usage: sudo $0 <username> [full-name]

  <username>   login name (lowercase, no spaces)
  [full-name]  shown on the login screen (GECOS field)

Environment:
  OMARCHY_THEME  theme name to apply (default: $THEME)
EOF
}

username="${1:-}"
full_name="${2:-}"

if [[ ! -d "$OMARCHY_PATH" ]]; then
  echo "Error: OMARCHY_PATH '$OMARCHY_PATH' not found." >&2
  exit 1
fi

home="/home/$username"

if [[ $EUID -ne 0 ]]; then
  echo "Error: run this with sudo — it creates the account." >&2
  exit 1
fi

if [[ -z $username ]]; then
  usage >&2
  exit 1
fi

if ! [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "Error: '$username' is not a valid username (lowercase letters, digits, - and _)." >&2
  exit 1
fi

if getent passwd "$username" >/dev/null; then
  echo "==> Account '$username' already exists — continuing with the setup."
else
  # ------------------------------------------------------------------------
  # 1. The account
  # ------------------------------------------------------------------------
  echo "==> Creating account '$username'"
  # No -G wheel: this account gets no sudo and no root access.
  useradd -m -s /bin/bash ${full_name:+-c "$full_name"} "$username"
fi
uid="$(id -u "$username")"

# Temporary password. The owner replaces it with something memorable:
#   sudo passwd $username
temp_password="$(head -c 128 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-20)"
printf '%s:%s\n' "$username" "$temp_password" | chpasswd
(umask 077; printf '%s\n' "$temp_password" >"/root/omarchy-user-$username.password")

# systemd-logind's per-user runtime dir. Created here so the setup below has
# an XDG_RUNTIME_DIR to write to; logind reuses it at first login.
install -d -m 700 -o "$uid" -g "$uid" "/run/user/$uid"

# --------------------------------------------------------------------------
# 2. The Omarchy user setup
# --------------------------------------------------------------------------
echo "==> Seeding the Omarchy user setup"
runuser -u "$username" -- env \
  --chdir="$home" \
  HOME="$home" \
  USER="$username" \
  LOGNAME="$username" \
  SHELL=/bin/bash \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_DATA_HOME="$home/.local/share" \
  XDG_CACHE_HOME="$home/.cache" \
  XDG_STATE_HOME="$home/.local/state" \
  XDG_RUNTIME_DIR="/run/user/$uid" \
  OMARCHY_PATH="$OMARCHY_PATH" \
  OMARCHY_THEME="$THEME" \
  OMARCHY_USER_NAME="${full_name:-$username}" \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  bash -s <<'USER_SETUP'
set -euo pipefail

export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
source "$OMARCHY_PATH/default/bash/env-bootstrap"

# --- theme ---------------------------------------------------------------
# Headless: there is no live shell to repaint. The terminals, bar and Hyprland
# all read the generated files out of ~/.local/state/omarchy/current/theme.
OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "$OMARCHY_THEME"

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/omarchy/current/theme/btop.theme" ~/.config/btop/themes/current.theme

# --- GNOME keyring -------------------------------------------------------
bash "$OMARCHY_PATH/install/user/default-keyring.sh"

# --- XCompose and git identity ------------------------------------------
bash "$OMARCHY_PATH/install/user/xcompose.sh"
bash "$OMARCHY_PATH/install/user/git.sh"

# --- Chromium native messaging hosts ------------------------------------
bash "$OMARCHY_PATH/install/user/chromium.sh"

# --- XDG directories and GTK bookmarks -----------------------------------
mkdir -p ~/Downloads ~/Pictures ~/Videos ~/.config/gtk-3.0
xdg-user-dirs-update --set TEMPLATES "$HOME"
xdg-user-dirs-update --set PUBLICSHARE "$HOME"
xdg-user-dirs-update --set DESKTOP "$HOME"
rmdir ~/Templates ~/Public ~/Desktop 2>/dev/null || true
touch ~/.config/gtk-3.0/bookmarks
for dir in Downloads Projects Pictures Videos; do
  bookmark="file://$HOME/$dir $dir"
  grep -qxF "$bookmark" ~/.config/gtk-3.0/bookmarks || echo "$bookmark" >>~/.config/gtk-3.0/bookmarks
done

# --- app launchers -------------------------------------------------------
# Not omarchy-refresh-applications: that also runs install/user/mise.sh, which
# installs the whole AI-agent toolchain (~1.5 GB). Copy the launchers instead.
mkdir -p ~/.local/share/applications
cp "$OMARCHY_PATH"/applications/*.desktop ~/.local/share/applications/
if omarchy-cmd-present alacritty; then
  cp "$OMARCHY_PATH"/default/alacritty/Alacritty.desktop ~/.local/share/applications/
fi
update-desktop-database ~/.local/share/applications

# --- default browser and mail handler ------------------------------------
env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings set default-web-browser chromium.desktop
xdg-mime default HEY.desktop x-scheme-handler/mailto

# --- work directory ------------------------------------------------------
# The installer's mise-work.sh also downloads Node here; skip that.
mkdir -p "$HOME/Work" "$HOME/Work/tries"

# --- tell Omarchy the user is finalized ----------------------------------
# Without this marker, the first login runs omarchy-provision-user, which
# installs the AI agents and coding tools for this account.
omarchy-done mark finalize-user
USER_SETUP

# --------------------------------------------------------------------------
# 3. Summary
# --------------------------------------------------------------------------
cat <<EOF

Done.

  username   $username
  home       $home
  sudo       no (not in wheel)
  theme      $THEME

Temporary password (also saved to /root/omarchy-user-$username.password):
  $temp_password

Next steps:
  * Set a password the child can type:   sudo passwd $username
  * Log out of your session, pick '$username' at the SDDM greeter, and log in.
    The first login runs the rest of the Omarchy first-run setup for that user.
  * Nothing is installed for this account beyond the desktop: the AI-agent
    toolchain (install/user/mise.sh) is deliberately skipped. Run
    'sudo -iu $username omarchy-provision-user --force' if you want it.
EOF
