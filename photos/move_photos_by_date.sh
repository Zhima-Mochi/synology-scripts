#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Photo Date Organizer (refactored)
# ---------------------------------------------------------------------------
#  Moves photos into a year/month directory structure based on their EXIF
#  "DateTimeOriginal" metadata (falls back to file mtime when missing).
#
#  Features
#  --------
#  • Accepts a single file or a directory (with optional recursive search)
#  • Auto‑creates target/⟨YYYY⟩/⟨MM⟩ folders
#  • Filename collisions are resolved by appending a timestamp suffix
#  • Strict error handling (`set -euo pipefail`)
#
#  Dependencies
#  ------------
#  * exiftool – install via your package manager, e.g. 
#      sudo apt-get install libimage-exiftool-perl
#
#  Usage
#  -----
#    $ move_photos_by_date.sh [OPTIONS] <source_path> <target_root>
#
#  Options
#    -r, --recursive   Walk sub‑directories under <source_path>
#    -h, --help        Show this help and exit
# ---------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/file_utils.sh"

SCRIPT_NAME=$(basename "$0")

# ----------------------------- helper functions ----------------------------

print_usage() {
  printf "\nUsage: %s [OPTIONS] <source_path> <target_root>\n" "$SCRIPT_NAME"
  sed -n '1,/^# ---------------------------------------------------------------------------/{s/^# \{0,1\}//;p;}' "$0" | grep -E "^(  |\* |• |-|Usage|Options)" || true
}

# ---------------------------------------------------------------------------
#  move_photo <file> <target_root>
# ---------------------------------------------------------------------------
move_photo() {
  local src="$1" tgt_root="$2"
  is_image "$src" || return 0

  local ts_taken year month
  ts_taken=$(get_photo_date "$src")
  year=${ts_taken%%:*}
  month=${ts_taken#*:}; month=${month%%:*}

  local dest_dir="$tgt_root/$year/$month"
  mkdir -p -- "$dest_dir"

  local base fn ext
  base=$(basename -- "$src")
  fn=${base%.*}
  ext=${base##*.}

  local dest="$dest_dir/$base"
  if [[ -e "$dest" ]]; then
    dest="$dest_dir/${fn}_$(date +%Y%m%d%H%M%S).${ext,,}"
  fi

  printf '→  %s\n   ↳ %s\n' "$src" "$dest"
  mv -- "$src" "$dest"
}

# ---------------------------------------------------------------------------
#  main
# ---------------------------------------------------------------------------
main() {
  require_cmd exiftool
  require_cmd file

  local recursive=false
  local -a positional=()

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--recursive) recursive=true ; shift ;;
      -h|--help) print_usage; exit 0 ;;
      -*) die "Unknown option: $1" ;;
      *) positional+=("$1"); shift ;;
    esac
  done

  [[ ${#positional[@]} -eq 2 ]] || die "Missing required arguments.\nTry --help for usage."

  local src=${positional[0]} tgt_root=${positional[1]}
  [[ -e "$src" ]] || die "Source path '$src' does not exist"
  mkdir -p -- "$tgt_root"

  if [[ -f "$src" ]]; then
    move_photo "$src" "$tgt_root"
  else
    local -a find_opts=()
    $recursive || find_opts+=(-maxdepth 1)
    find_opts+=(-type f)
    while IFS= read -r -d '' file; do
      # skip SYNOPHOTO_THUMB
      if [[ "$file" == *"SYNOPHOTO_THUMB"* ]]; then
        continue
      fi

      move_photo "$file" "$tgt_root"
    done < <(find "$src" "${find_opts[@]}" -print0)
  fi

  print_success "\n✔  Processing complete."
}

main "$@"
