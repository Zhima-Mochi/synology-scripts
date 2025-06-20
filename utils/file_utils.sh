#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Media Utilities Library
# ---------------------------------------------------------------------------
# Shared functions for media management scripts
# ---------------------------------------------------------------------------

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Source basic utilities
source "$(dirname "${BASH_SOURCE[0]}")/basic_utils.sh"

# ------ File System Utilities ------

# Check if file is an image
is_image() { file -Lb --mime-type -- "$1" | grep -qE '^image/(jpeg|png|gif|bmp|tiff|heic|x-canon-cr2|x-sony-arw)$'; }

# Check if file is a video
is_video() { file -Lb --mime-type -- "$1" | grep -qE '^video/(mp4|quicktime|x-msvideo|x-matroska)$'; }

# Check if file is a supported media file (photo or video)
is_media() { is_image "$1" || is_video "$1"; }

# Build find arguments for photos
# Usage: build_find_args <dir> <recursive> <name_patterns_array_ref>
build_find_args() {
    local dir="$1"
    local recursive="$2"
    local -n patterns=$3 # Use nameref for the array
    local after_time="${4:-}"
    local before_time="${5:-}"

    local -a args=("$dir")

    if [[ "$recursive" != "true" ]]; then
        args+=("-maxdepth" "1")
    fi

    if [[ -n "$after_time" ]]; then
        args+=(-newermt "@$after_time")
    fi

    if [[ -n "$before_time" ]]; then
        args+=('!' -newermt "@$before_time")
    fi

    args+=("-type" "f")

    if [[ ${#patterns[@]} -gt 0 ]]; then
        args+=("(")
        local first=true
        for pattern in "${patterns[@]}"; do
            if ! $first; then
                args+=("-o")
            fi
            args+=("-iname" "$pattern")
            first=false
        done
        args+=(")")
    fi

    # Return the arguments as a list
    for arg in "${args[@]}"; do
        echo "$arg"
    done
}

# ------ EXIF/Metadata Utilities ------

# Try several EXIF fields and fall back to filesystem mtime
# Returns date in YYYY:MM:DD HH:MM:SS format
get_photo_date() {
  local path="$1"
  local exif_fields=(DateTimeOriginal CreateDate ModifyDate)
  local d=""
  
  require_cmd exiftool
  
  for f in "${exif_fields[@]}"; do
    d=$(exiftool -s -s -s -d "%Y:%m:%d %H:%M:%S" "-$f" -- "$path" 2>/dev/null || true)
    [[ -n "$d" && ! "$d" =~ ^0000 ]] && break
  done
  
  # fallback – filesystem mtime
  [[ -z "$d" ]] && d=$(date -r "$path" +"%Y:%m:%d %H:%M:%S")
  printf '%s' "$d"
}

# Get date from video file metadata
# Returns date in YYYY:MM:DD HH:MM:SS format
get_video_date() {
  local path="$1"
  local metadata_fields=(DateTimeOriginal CreateDate TrackCreateDate MediaCreateDate)
  local d=""
  
  require_cmd exiftool
  
  for f in "${metadata_fields[@]}"; do
    d=$(exiftool -s -s -s -d "%Y:%m:%d %H:%M:%S" "-$f" -- "$path" 2>/dev/null || true)
    [[ -n "$d" && ! "$d" =~ ^0000 ]] && break
  done
  
  # fallback – filesystem mtime
  [[ -z "$d" ]] && d=$(date -r "$path" +"%Y:%m:%d %H:%M:%S")
  printf '%s' "$d"
}

# Get date from any media file (photo or video)
# Returns date in YYYY:MM:DD HH:MM:SS format
get_media_date() {
  local path="$1"
  
  if is_image "$path"; then
    get_photo_date "$path"
  elif is_video "$path"; then
    get_video_date "$path"
  else
    # fallback – filesystem mtime for unknown media types
    date -r "$path" +"%Y:%m:%d %H:%M:%S"
  fi
}

# Update EXIF metadata timestamps
update_exif_timestamps() {
  local file="$1"
  local timestamp="$2"
  
  require_cmd exiftool
  
  # Format the timestamp for EXIF
  local fmt_exif=$(date -d "@$timestamp" +'%Y:%m:%d %H:%M:%S')
  
  # Update EXIF metadata, preserve filesystem mtime
  exiftool -overwrite_original -P \
    -DateTimeOriginal="$fmt_exif" \
    -CreateDate="$fmt_exif" \
    -ModifyDate="$fmt_exif" \
    "$file" &>/dev/null
}

# Update video metadata timestamps
update_video_timestamps() {
  local file="$1"
  local timestamp="$2"
  
  require_cmd exiftool
  
  # Format the timestamp for metadata
  local fmt_meta=$(date -d "@$timestamp" +'%Y:%m:%d %H:%M:%S')
  
  # Update video metadata, preserve filesystem mtime
  exiftool -overwrite_original -P \
    -DateTimeOriginal="$fmt_meta" \
    -CreateDate="$fmt_meta" \
    -ModifyDate="$fmt_meta" \
    -TrackCreateDate="$fmt_meta" \
    -TrackModifyDate="$fmt_meta" \
    -MediaCreateDate="$fmt_meta" \
    -MediaModifyDate="$fmt_meta" \
    "$file" &>/dev/null
}

# Update media file timestamps (works for both photos and videos)
update_media_timestamps() {
  local file="$1"
  local timestamp="$2"
  
  if is_image "$file"; then
    update_exif_timestamps "$file" "$timestamp"
  elif is_video "$file"; then
    update_video_timestamps "$file" "$timestamp"
  fi
}

# ------ Test Utilities ------

# Create a test image with optional EXIF date
create_test_image() {
  local file_path="$1"
  local date_str="${2:-}"
  
  require_cmd convert
  
  # Ensure the directory exists
  local dir_path=$(dirname "$file_path")
  mkdir -p "$dir_path"
  
  # Create a simple 10x10 JPEG image
  convert -size 10x10 xc:white "$file_path"
  
  # Set the EXIF date if provided
  if [[ -n "$date_str" ]]; then
    require_cmd exiftool
    exiftool -overwrite_original "-DateTimeOriginal=$date_str" "$file_path" >/dev/null
    print_info "Created test image: $file_path with date: $date_str"
  else
    print_info "Created test image: $file_path (no EXIF date)"
  fi
}

# Create a test video file with optional metadata date
create_test_video() {
  local file_path="$1"
  local date_str="${2:-}"
  
  require_cmd ffmpeg
  
  # Ensure the directory exists
  local dir_path=$(dirname "$file_path")
  mkdir -p "$dir_path"
  
  # Create a simple 1-second video
  ffmpeg -f lavfi -i color=c=blue:s=10x10:d=1 -c:v libx264 -t 1 -y "$file_path" &>/dev/null
  
  # Set the metadata date if provided
  if [[ -n "$date_str" ]]; then
    require_cmd exiftool
    exiftool -overwrite_original "-DateTimeOriginal=$date_str" "-CreateDate=$date_str" "$file_path" >/dev/null
    print_info "Created test video: $file_path with date: $date_str"
  else
    print_info "Created test video: $file_path (no metadata date)"
  fi
}