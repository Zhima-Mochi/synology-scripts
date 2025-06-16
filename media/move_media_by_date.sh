#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Media Date Organizer
# ---------------------------------------------------------------------------
#  Moves media files (photos and videos) into a year/month directory structure 
#  based on their EXIF/metadata "DateTimeOriginal" (falls back to file mtime when missing).
#
#  Features
#  --------
#  • Accepts a single file or a directory (with optional recursive search)
#  • Auto‑creates target/⟨YYYY⟩/⟨MM⟩ folders
#  • Filename collisions are resolved by appending a timestamp suffix
#  • Strict error handling (`set -euo pipefail`)
#  • Supports common photo formats (jpg, png, etc.) and video formats (mp4, mov, etc.)
#
#  Dependencies
#  ------------
#  * exiftool – install via your package manager, e.g. 
#      sudo apt-get install libimage-exiftool-perl
#
#  Usage
#  -----
#    $ move_media_by_date.sh [OPTIONS] <source_path> <target_root>
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
#  move_media <file> <target_root>
# ---------------------------------------------------------------------------
move_media() {
  local src="$1" tgt_root="$2"
  local owner=$(stat -c '%U' "$tgt_root")
  is_media "$src" || return 0

  local ts_taken year month
  ts_taken=$(get_media_date "$src")
  year=${ts_taken%%:*}
  month=${ts_taken#*:}; month=${month%%:*}

  local dest_dir="$tgt_root/$year/$month"
  mkdir -p -- "$dest_dir"
  chown "$owner" "$dest_dir"

  local base fn ext
  base=$(basename -- "$src")
  fn=${base%.*}
  ext=${base##*.}

  # Start with the original filename
  local dest="$dest_dir/$base"
  local counter=1
  
  # If destination exists, try with counter suffix
  while [[ -e "$dest" ]]; do
    dest="$dest_dir/${fn}_${counter}.${ext,,}"
    ((counter++))
  done

  printf '→  %s\n   ↳ %s\n' "$src" "$dest"
  mv -- "$src" "$dest"
  chown "$owner" "$dest"
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
    move_media "$src" "$tgt_root"
  else
    local -a find_opts=()
    $recursive || find_opts+=(-maxdepth 1)
    find_opts+=(-type f)
    while IFS= read -r -d '' file; do
      # skip SYNOPHOTO_THUMB
      if [[ "$file" == *"SYNOPHOTO_THUMB"* ]]; then
        continue
      fi

      move_media "$file" "$tgt_root"
    done < <(find "$src" "${find_opts[@]}" -print0)
  fi

  print_success "\n✔  Processing complete."
}

main "$@" 