#!/usr/bin/env bash
#
# Download offline reference books (Kiwix ZIM files) for the child account.
#
# Run this while the machine still has internet -- afterwards everything works
# offline via `kiwix-serve` (a local web server) or the `zim` desktop reader.
#
#   ./download-offline-books.sh              # download everything (~21 GB)
#   ./download-offline-books.sh --small      # only the small topical books (~2.7 GB)
#   ./download-offline-books.sh --verify     # just report what is present
#
set -euo pipefail

ZIM_DIR="${ZIM_DIR:-/usr/share/kiwix/zim}"
BASE="https://download.kiwix.org/zim"

# name:path-in-archive:human label
BOOKS=(
  # --- the encyclopedia -----------------------------------------------------
  "wikipedia_en_all_mini_2026-09.zim:wikipedia:The whole of Wikipedia, text only (13 GB) -- the big offline reference"
  "wikipedia_en_100_2026-08.zim:wikipedia:Wikipedia's 100 most important articles (318 MB) -- quick start"
  # --- school subjects ------------------------------------------------------
  "wikipedia_en_astronomy_nopic_2026-08.zim:wikipedia:Astronomy (385 MB) -- space, planets, stars"
  "wikipedia_en_mathematics_mini_2026-06.zim:wikipedia:Mathematics (56 MB) -- numbers, shapes, formulas"
  "wikipedia_en_chemistry_mini_2026-10.zim:wikipedia:Chemistry (22 MB) -- the periodic table and elements"
  "wikipedia_en_geography_nopic_2026-10.zim:wikipedia:Geography (586 MB) -- countries, rivers, mountains"
  "wikipedia_en_history_nopic_2026-10.zim:wikipedia:History (736 MB) -- people, events, eras"
  "wikipedia_en_computer_nopic_2026-09.zim:wikipedia:Computers (493 MB) -- how computers work"
  # --- textbooks and study resources ---------------------------------------
  "wikibooks_en_all_nopic_2026-04.zim:wikibooks:Free textbooks (3.3 GB) -- for school projects"
  "wikiversity_en_all_nopic_2026-08.zim:wikiversity:Learning resources (1.5 GB) -- worksheets and study guides"
)

SMALL_BOOKS=(
  "wikipedia_en_100_2026-08.zim:wikipedia:Wikipedia's 100 most important articles (318 MB) -- quick start"
  "wikipedia_en_astronomy_nopic_2026-08.zim:wikipedia:Astronomy (385 MB) -- space, planets, stars"
  "wikipedia_en_mathematics_mini_2026-06.zim:wikipedia:Mathematics (56 MB) -- numbers, shapes, formulas"
  "wikipedia_en_chemistry_mini_2026-10.zim:wikipedia:Chemistry (22 MB) -- the periodic table and elements"
  "wikipedia_en_geography_nopic_2026-10.zim:wikipedia:Geography (586 MB) -- countries, rivers, mountains"
  "wikipedia_en_computer_nopic_2026-09.zim:wikipedia:Computers (493 MB) -- how computers work"
)

# The ZIM directory has to be readable by every local account.
prepare_dir() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run this with sudo (it writes to $ZIM_DIR)." >&2
    exit 1
  fi
  install -d -o root -g users -m 0755 "$ZIM_DIR"
}

list_books() {
  printf '%-42s %-12s %s\n' "FILE" "SIZE" "STATUS"
  for entry in "${BOOKS[@]}"; do
    file="${entry%%:*}"
    if [[ -f "$ZIM_DIR/$file" ]]; then
      status="present ($(du -h "$ZIM_DIR/$file" | cut -f1))"
    else
      status="missing"
    fi
    printf '%-42s %-12s %s\n' "$file" "-" "$status"
  done
}

case "${1:-}" in
  --verify)
    list_books
    exit 0
    ;;
  --small)
    BOOKS=("${SMALL_BOOKS[@]}")
    ;;
esac

prepare_dir

for entry in "${BOOKS[@]}"; do
  file="${entry%%:*}"
  rest="${entry#*:}"
  path="${rest%%:*}"
  label="${rest#*:}"

  target="$ZIM_DIR/$file"
  if [[ -f "$target" ]]; then
    echo "==> SKIP $file (already downloaded)"
    continue
  fi

  url="$BASE/$path/$file"
  echo "==> Downloading $file"
  echo "    $label"
  # -C - resumes a partial download; --retry survives a flaky mirror.
  curl -fL -C - --retry 5 --retry-delay 5 --connect-timeout 30 \
       --progress-bar -o "$target.part" "$url" || {
    echo "!!! FAILED: $file" >&2
    rm -f "$target.part"
    continue
  }
  mv "$target.part" "$target"
  chmod 0644 "$target"
  chown root:root "$target"
done

echo
echo "=== Downloaded books ==="
list_books
