#!/usr/bin/env bash
#
# Fix and build the AUR packages that fail with the current toolchain:
#
#   sdl2_pango      -- upstream git repo lost the exec bit on ./configure
#   tuxpaint        -- drawing program for young children (depends on sdl2_pango)
#   tuxpaint-stamps -- upstream tarball lost the exec bit on ./install-stamps.sh
#
# Both failures are just missing executable bits, so we patch the PKGBUILD and
# build as the normal user (makepkg refuses to run as root). The resulting
# packages are then installed with a single pkexec call.
#
#   ./build-aur-fixes.sh          # build + install
#   ./build-aur-fixes.sh --build  # build only, print the package paths
#
set -euo pipefail

BUILD_ROOT="${AUR_BUILD_ROOT:-$HOME/.cache/kid-aur}"
mkdir -p "$BUILD_ROOT"

# Packages are collected here and installed together in one go.
PKG_FILES=()

fetch() {
  local pkg="$1" dir="$BUILD_ROOT/$1"
  mkdir -p "$dir"
  curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$pkg" -o "$dir/PKGBUILD"
}

# Extra source files that live in the AUR repo next to the PKGBUILD.
# (They are plain "name" entries in source=(), not URLs, so makepkg cannot
# fetch them by itself.)
fetch_extra_sources() {
  local pkg="$1"; shift
  local dir="$BUILD_ROOT/$pkg" file
  for file in "$@"; do
    if [[ ! -f "$dir/$file" ]]; then
      echo "==> Fetching extra source $file for $pkg"
      curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/$file?h=$pkg" \
        -o "$dir/$file"
    fi
  done
}

# Build one package, remember the resulting .pkg.tar.zst.
# The glob deliberately excludes the "-debug" split package.
build() {
  local name="$1" dir="$BUILD_ROOT/$1"
  echo
  echo "==> Building $name in $dir"
  # --nodeps: sdl2_pango is not installed yet while tuxpaint is being built.
  # All real dependencies are checked by pacman when the packages are installed.
  (cd "$dir" && makepkg -sf --noconfirm --nocheck --nodeps) || {
    echo "!!! BUILD FAILED: $name" >&2
    return 1
  }
  local pkgfile
  pkgfile="$(ls -1t "$dir/$name"-[0-9]*.pkg.tar.zst 2>/dev/null \
    | grep -v -- '-debug-' | head -1 || true)"
  [[ -n "$pkgfile" ]] || {
    echo "!!! no package produced for $name" >&2
    return 1
  }
  PKG_FILES+=("$pkgfile")
}

# --- sdl2_pango --------------------------------------------------------------

fetch sdl2_pango
# The PKGBUILD also needs the freetype2.patch source file from the AUR repo.
fetch_extra_sources sdl2_pango freetype2.patch
# The upstream repo commits ./configure without the executable bit.
perl -0pi -e 's{(  cd "\$srcdir/\$pkgname-\$_commit"\n)}{$1  chmod +x configure\n}' \
  "$BUILD_ROOT/sdl2_pango/PKGBUILD"
grep -q 'chmod +x configure' "$BUILD_ROOT/sdl2_pango/PKGBUILD" ||
  { echo "!!! the sdl2_pango patch did not apply" >&2; exit 1; }

build sdl2_pango

# --- tuxpaint ----------------------------------------------------------------

fetch tuxpaint
fetch_extra_sources tuxpaint 6271edececef2a3720e5a5b4e245407cf909f034.patch
build tuxpaint

# --- tuxpaint-stamps ---------------------------------------------------------

fetch tuxpaint-stamps
# The SourceForge mirror is flaky; download the tarball ourselves if needed.
stamps_tarball="$BUILD_ROOT/tuxpaint-stamps/tuxpaint-stamps-2025.05.26.tar.gz"
if [[ ! -f "$stamps_tarball" ]]; then
  echo "==> Downloading tuxpaint-stamps tarball"
  curl -fL --retry 5 --retry-delay 3 \
    -o "$stamps_tarball" \
    "https://downloads.sourceforge.net/tuxpaint/tuxpaint-stamps-2025.05.26.tar.gz"
fi
perl -0pi -e 's{(build\(\) \{\n)}{$1  chmod +x "\$pkgname-\$pkgver"/install-stamps.sh\n}' \
  "$BUILD_ROOT/tuxpaint-stamps/PKGBUILD"
grep -q 'chmod +x "\$pkgname-\$pkgver"/install-stamps.sh' "$BUILD_ROOT/tuxpaint-stamps/PKGBUILD" ||
  { echo "!!! the tuxpaint-stamps patch did not apply" >&2; exit 1; }

build tuxpaint-stamps

echo
echo "==> Built packages:"
printf '    %s\n' "${PKG_FILES[@]}"

if [[ "${1:-}" == "--build" ]]; then
  echo
  echo "(--build mode: not installing)"
  exit 0
fi

echo
echo "==> Installing"
pkexec pacman -U --noconfirm "${PKG_FILES[@]}"

echo
echo "=== Result ==="
pacman -Qq | grep -E '^(sdl2_pango|tuxpaint|tuxpaint-stamps)$' | sort
