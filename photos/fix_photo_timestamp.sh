#!/usr/bin/env bash

# Fix photo timestamps using filenames

set -euo pipefail
IFS=$'\n\t'

# Show usage
show_usage() {
  echo "Usage: $0 -d <PHOTO_DIR> [-a <AFTER_TIME>] [-b <BEFORE_TIME>]"
  echo "Time format for -a and -b: 'YYYY-MM-DD HH:MM:SS' or any format accepted by 'date -d'."
}

# Parse arguments
PHOTO_DIR=""
AFTER_TIME=""
BEFORE_TIME=""

require_cmd() { command -v "$1" &>/dev/null || { echo "'$1' command not found"; exit 1; }; }

main() {
  require_cmd exiftool

  while getopts "d:a:b:" opt; do
    case "$opt" in
    d) PHOTO_DIR=$OPTARG ;;
    a) AFTER_TIME=$(date -d "$OPTARG" +%s) || {
      show_usage
      exit 1
    } ;;
    b) BEFORE_TIME=$(date -d "$OPTARG" +%s) || {
      show_usage
      exit 1
    } ;;
    *)
      show_usage >&2
      exit 1
      ;;
    esac
  done

  [[ -z "$PHOTO_DIR" ]] && {
    show_usage >&2
    exit 1
  }

  # Build find arguments
  find_args=( "$PHOTO_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) )

  # If AFTER_TIME is specified, add condition for files newer than that time
  if [[ -n $AFTER_TIME ]]; then
    after_str=$(date -d "@$AFTER_TIME" +'%F %T')
    find_args+=( -newermt "$after_str" )
  fi

  # If BEFORE_TIME is specified, exclude files newer than that time
  if [[ -n $BEFORE_TIME ]]; then
    before_str=$(date -d "@$BEFORE_TIME" +'%F %T')
    find_args+=( ! -newermt "$before_str" )
  fi

  # Process only files that match the time criteria
  while IFS= read -r file; do
    base=$(basename "$file")
    name="${base%.*}"

    # Ensure filename is a valid timestamp
    [[ "$name" =~ ^[0-9]+$ ]] || {
      echo "Skipping invalid filename: $base"
      continue
    }

    ts=$name

    # Read the current timestamp of the file before updating
    current_timestamp=$(stat --format='%y' "$file")

    # Format the timestamp for touch command
    formatted_date=$(date -d "@$ts" +"%Y%m%d%H%M.%S")

    # Update filesystem timestamp using the formatted date
    touch -t "$formatted_date" "$file"

    # Generate proper EXIF timestamp
    fmt_exif=$(date -d "@$ts" +'%Y:%m:%d %H:%M:%S')
    modified_fmt_exif=$(date -d "@$ts" +'%Y:%m:%d %H:%M:%S')

    # Update EXIF metadata, preserve filesystem mtime
    exiftool -overwrite_original -P \
      -DateTimeOriginal="$fmt_exif" \
      -CreateDate="$fmt_exif" \
      -ModifyDate="$modified_fmt_exif" \
      "$file" &>/dev/null

    # Show what was updated with actual timestamps
    new_timestamp=$(stat --format='%y' "$file")
    timestamp_date=$(date -d "@$ts" +"%Y-%m-%d %H:%M:%S")
    echo "Updated: $base from $current_timestamp to $new_timestamp (Unix timestamp: $ts = $timestamp_date)"

  done < <(find "${find_args[@]}")
}

main "$@"
