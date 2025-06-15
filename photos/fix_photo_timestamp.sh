#!/usr/bin/env bash

# Fix photo timestamps using filenames

set -euo pipefail
IFS=$'\n\t'

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/file_utils.sh"

# Show usage
show_usage() {
  echo "Usage: $0 <PHOTO_DIR> [-a <AFTER_TIME>] [-b <BEFORE_TIME>] [-r]"
  echo "Time format for -a and -b: 'YYYY-MM-DD HH:MM:SS' or any format accepted by 'date -d'."
  echo "  -r: Process directories recursively (default: off)"
}

main() {
  require_cmd exiftool

  if [[ $# -eq 0 || "$1" == "-"* ]]; then
    show_usage >&2
    exit 1
  fi
  local PHOTO_DIR="$1"
  shift

  local RECURSIVE=false
  local AFTER_TIME=""
  local BEFORE_TIME=""
  
  # Parse command line options
  while getopts "a:b:r" opt; do
    case "$opt" in
    a)
      AFTER_TIME=$(date -d "$OPTARG" +%s) || {
        show_usage
        exit 1
      }
      ;;
    b)
      BEFORE_TIME=$(date -d "$OPTARG" +%s) || {
        show_usage
        exit 1
      }
      ;;
    r) RECURSIVE=true ;;
    *)
      show_usage >&2
      exit 1
      ;;
    esac
  done

  # Validate required parameters
  [[ ! -d "$PHOTO_DIR" ]] && {
    die "Error: '$PHOTO_DIR' is not a directory"
  }

  # Get find arguments for photos
  local -a photo_patterns=('*.jpg' '*.jpeg')
  mapfile -t find_args < <(build_find_args "$PHOTO_DIR" "$RECURSIVE" photo_patterns "$AFTER_TIME" "$BEFORE_TIME")

  # Process files that match the criteria
  while IFS= read -r file; do
    base=$(basename "$file")
    name="${base%.*}"

    # Ensure filename is a valid timestamp
    [[ "$name" =~ ^[0-9]+$ ]] || {
      print_info "Skipping invalid filename: $base"
      continue
    }

    ts=$name
    
    # If the length of the timestamp is 13 digits, assume it's milliseconds since epoch and truncate to seconds
    if [[ ${#ts} -eq 13 ]]; then
      ts=${ts:0:10}
    elif [[ ${#ts} -ne 10 ]]; then
      print_info "Skipping invalid timestamp: $base"
      continue
    fi

    # Read the current timestamp of the file before updating
    current_timestamp=$(stat --format='%y' "$file")

    # Format the timestamp for touch command
    formatted_date=$(date -d "@$ts" +"%Y%m%d%H%M.%S" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
      print_info "Skipping invalid timestamp: $base"
      continue
    fi

    # Update filesystem timestamp using the formatted date
    touch -t "$formatted_date" "$file"

    # Update EXIF metadata
    update_exif_timestamps "$file" "$ts"

    # Show what was updated with actual timestamps
    new_timestamp=$(stat --format='%y' "$file")
    timestamp_date=$(date -d "@$ts" +"%Y-%m-%d %H:%M:%S")
    print_success "Updated: $base from $current_timestamp to $new_timestamp (Unix timestamp: $ts = $timestamp_date)"

  done < <(find "${find_args[@]}")
}

main "$@"
