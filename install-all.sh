#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Omarchy Kid Setup ==="
echo "This will set up a kid-friendly environment."
echo ""

# 1. User setup
read -p "Create/setup child user? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/add-omarchy-user.sh"
fi

# 2. Main apps
read -p "Install kid apps and games? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/install-kid-apps.sh"
fi

# 3. Extra games
read -p "Install extra GNOME games? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/install-kid-games-extra.sh"
fi

# 4. AUR fixes
read -p "Build and install AUR packages (TuxPaint, etc.)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/scripts/build-aur-fixes.sh"
fi

# 5. Download books
read -p "Download offline books (requires internet, large download)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/download-offline-books.sh"
fi

# 6. Install books
read -p "Wire up offline books? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/install-offline-books.sh"
fi

# 7. Menu
read -p "Create kid-friendly menu for edi? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo "$SCRIPT_DIR/scripts/setup-kid-menu.sh" edi
    sudo -iu edi systemctl --user restart omarchy-shell 2>/dev/null || true
fi

echo ""
echo "=== Setup complete ==="
