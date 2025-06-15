#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Photo Date Organizer (refactored)
# ---------------------------------------------------------------------------
#  Moves photos into a year/month directory structure based on their EXIF
#  "DateTimeOriginal" metadata (falls back to file mtime when missing).
#
#  Features
#  --------
#  • Accepts a single file or a directory (with optional recursive search)
#  • Auto‑creates target/⟨YYYY⟩/⟨MM⟩ folders
#  • Filename collisions are resolved by appending a timestamp suffix
#  • Strict error handling (`set -euo pipefail`)
#
#  Dependencies
#  ------------
#  * exiftool – install via your package manager, e.g. 
#      sudo apt-get install libimage-exiftool-perl
#
#  Usage
#  -----
#    $ %s [OPTIONS] <source_path> <target_root>
#
#  Options
#    -r, --recursive   Walk sub‑directories under <source_path>
#    -h, --help        Show this help and exit
# ---------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")

# ----------------------------- helper functions ----------------------------

print_usage() {
  printf "\nUsage: %s [OPTIONS] <source_path> <target_root>\n" "$SCRIPT_NAME"
  sed -n '1,/^# ---------------------------------------------------------------------------/{s/^# \{0,1\}//;p;}' "$0" | grep -E "^(  |\* |• |-|Usage|Options)" || true
}

die() { printf "❌  %s\n" "$1" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'%s' command not found" "$1"; }

# Determine if file seems to be an image we can process
is_image() { file -Lb --mime-type -- "$1" | grep -qE '^image/(jpeg|png|gif|bmp|tiff|heic|x-canon-cr2|x-sony-arw)$'; }

# Try several EXIF fields and finally fall back to filesystem mtime
# Returns date in YYYY:MM:DD HH:MM:SS format via stdout
get_taken_date() {
  local path="$1"
  local exif_fields=(DateTimeOriginal CreateDate ModifyDate)
  local d=""
  for f in "${exif_fields[@]}"; do
    d=$(exiftool -s -s -s -d "%Y:%m:%d %H:%M:%S" "-$f" -- "$path" 2>/dev/null || true)
    [[ -n "$d" && ! "$d" =~ ^0000 ]] && break
  done
  # fallback – filesystem mtime
  [[ -z "$d" ]] && d=$(date -r "$path" +"%Y:%m:%d %H:%M:%S")
  printf '%s' "$d"
}

# ---------------------------------------------------------------------------
#  move_photo <file> <target_root>
# ---------------------------------------------------------------------------
move_photo() {
  local src="$1" tgt_root="$2"
  is_image "$src" || return 0

  local ts_taken year month
  ts_taken=$(get_taken_date "$src")
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
  local -a positional



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
    local -a find_opts=(-type f)
    $recursive || find_opts+=( -maxdepth 1 )
    while IFS= read -r -d '' file; do
      move_photo "$file" "$tgt_root"
    done < <(find "$src" "${find_opts[@]}" -print0)
  fi

  printf '\n✔  Processing complete.\n'
}

main "$@"
