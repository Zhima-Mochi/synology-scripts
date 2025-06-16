#!/usr/bin/env bash

# Fix media (photos and videos) timestamps using filenames

set -euo pipefail
IFS=$'\n\t'

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/file_utils.sh"

# Show usage
show_usage() {
  echo "Usage: $0 <MEDIA_DIR> [-a <AFTER_TIME>] [-b <BEFORE_TIME>] [-r] [-m <TARGET_DIR>]"
  echo "Time format for -a and -b: 'YYYY-MM-DD HH:MM:SS' or any format accepted by 'date -d'."
  echo "  -r: Process directories recursively (default: off)"
  echo "  -m <TARGET_DIR>: Target directory for moving media after fixing timestamps"
}

main() {
  require_cmd exiftool

  local RECURSIVE=false
  local AFTER_TIME=""
  local BEFORE_TIME=""
  local MOVE_MEDIA=false
  local MOVE_TARGET_DIR=""
  local MEDIA_DIR=""

  # Parse command line options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--recursive)
        RECURSIVE=true
        shift
        ;;
      -a|--after)
        AFTER_TIME=$(date -d "$2" +%s) || {
          show_usage
          exit 1
        }
        shift 2
        ;;
      -b|--before)
        BEFORE_TIME=$(date -d "$2" +%s) || {
          show_usage
          exit 1
        }
        shift 2
        ;;
      -m|--move)
        MOVE_MEDIA=true
        MOVE_TARGET_DIR="$2"
        shift 2
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      -*)
        show_usage >&2
        exit 1
        ;;
      *)
        if [[ -z "$MEDIA_DIR" ]]; then
          MEDIA_DIR="$1"
        else
          show_usage >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Check if media directory was provided
  if [[ -z "$MEDIA_DIR" ]]; then
    show_usage >&2
    exit 1
  fi

  # Validate required parameters
  [[ ! -d "$MEDIA_DIR" ]] && {
    die "Error: '$MEDIA_DIR' is not a directory"
  }

  # If moving media, ensure target directory exists
  if [[ "$MOVE_MEDIA" == true ]]; then
    if [[ -z "$MOVE_TARGET_DIR" ]]; then
      die "Error: Target directory not specified for -m option"
    fi
    mkdir -p "$MOVE_TARGET_DIR" || die "Error: Could not create target directory '$MOVE_TARGET_DIR'"
  fi

  # Get find arguments for media files
  local -a media_patterns=('*.jpg' '*.jpeg' '*.png' '*.gif' '*.mp4' '*.mov' '*.avi' '*.mkv')
  mapfile -t find_args < <(build_find_args "$MEDIA_DIR" "$RECURSIVE" media_patterns "$AFTER_TIME" "$BEFORE_TIME")

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
    update_media_timestamps "$file" "$ts"

    # Show what was updated with actual timestamps
    new_timestamp=$(stat --format='%y' "$file")
    timestamp_date=$(date -d "@$ts" +"%Y-%m-%d %H:%M:%S")
    print_success "Updated: $base from $current_timestamp to $new_timestamp (Unix timestamp: $ts = $timestamp_date)"

    if [[ "$MOVE_MEDIA" == true ]]; then
      "$SCRIPT_DIR/move_media_by_date.sh" "$file" "$MOVE_TARGET_DIR"
    fi

  done < <(find "${find_args[@]}")
}

main "$@"
