#!/usr/bin/env bash
# Test script for move_media_by_date.sh

set -euo pipefail
IFS=$'\n\t'

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$SCRIPT_DIR/output/media"
TEST_TARGET_DIR="$TEST_OUTPUT_DIR/sorted"

# Source utility functions
source "$ROOT_DIR/utils/basic_utils.sh"
source "$ROOT_DIR/utils/file_utils.sh"

# Initialize test environment
setup_test_env() {
  print_header "Setting up test environment for move_media_by_date tests"
  
  # Create test directories
  mkdir -p "$TEST_OUTPUT_DIR"
  rm -rf "$TEST_OUTPUT_DIR"/* # Clean up old test files
  mkdir -p "$TEST_TARGET_DIR"
  
  # Create test media files with different dates in EXIF/metadata
  # Photos from different years
  create_test_image "$TEST_OUTPUT_DIR/photo_2019.jpg" "2019:05:15 12:30:45"
  create_test_image "$TEST_OUTPUT_DIR/photo_2020.jpg" "2020:07:22 08:15:30"
  create_test_image "$TEST_OUTPUT_DIR/photo_2021.jpg" "2021:03:10 16:45:20"
  
  # Photos from same year but different months
  create_test_image "$TEST_OUTPUT_DIR/photo_jan.jpg" "2022:01:05 10:00:00"
  create_test_image "$TEST_OUTPUT_DIR/photo_feb.jpg" "2022:02:15 11:30:00"
  create_test_image "$TEST_OUTPUT_DIR/photo_dec.jpg" "2022:12:25 09:45:00"
  
  # Photos with no EXIF date (will use file mtime)
  create_test_image "$TEST_OUTPUT_DIR/photo_no_exif_1.jpg"
  create_test_image "$TEST_OUTPUT_DIR/photo_no_exif_2.jpg"
  
  # Videos with different dates
  if command -v ffmpeg &>/dev/null; then
    create_test_video "$TEST_OUTPUT_DIR/video_2019.mp4" "2019:11:05 14:25:30"
    create_test_video "$TEST_OUTPUT_DIR/video_2020.mp4" "2020:08:12 20:15:10"
    create_test_video "$TEST_OUTPUT_DIR/video_2022.mp4" "2022:06:30 09:00:00"
  else
    print_warning "ffmpeg not found, skipping video test file creation"
    # Create dummy text files instead for testing
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/video_2019.mp4"
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/video_2020.mp4"
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/video_2022.mp4"
  fi
  
  # Create a subdirectory with additional files for testing the recursive option
  mkdir -p "$TEST_OUTPUT_DIR/subdir"
  create_test_image "$TEST_OUTPUT_DIR/subdir/photo_subdir_2018.jpg" "2018:03:15 13:45:00"
  create_test_image "$TEST_OUTPUT_DIR/subdir/photo_subdir_2021.jpg" "2021:09:01 17:30:00"
  
  if command -v ffmpeg &>/dev/null; then
    create_test_video "$TEST_OUTPUT_DIR/subdir/video_subdir_2021.mp4" "2021:05:15 11:20:00"
  else
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/subdir/video_subdir_2021.mp4"
  fi
  
  print_success "Test environment setup complete"
}

# Test the move_media_by_date script
run_tests() {
  print_header "Running move_media_by_date tests"
  
  cd "$ROOT_DIR"
  
  # Test 1: Move a single file
  print_info "Test 1: Move a single photo file"
  ./media/move_media_by_date.sh "$TEST_OUTPUT_DIR/photo_2019.jpg" "$TEST_TARGET_DIR"
  
  # Test 2: Move all files in a directory (non-recursive)
  print_info "Test 2: Move all media files in directory"
  ./media/move_media_by_date.sh "$TEST_OUTPUT_DIR" "$TEST_TARGET_DIR"
  
  # Test 3: Move files with recursive option
  print_info "Test 3: Move files recursively"
  ./media/move_media_by_date.sh -r "$TEST_OUTPUT_DIR" "$TEST_TARGET_DIR"
  
  # Test 4: Verify the directory structure
  print_info "Test 4: Verify the directory structure"
  find "$TEST_TARGET_DIR" -type d | sort
  
  # Test 5: List all moved media files
  print_info "Test 5: List all moved media files"
  find "$TEST_TARGET_DIR" -type f | sort
  
  print_success "All tests executed successfully"
}

# Main function
main() {
  print_header "STARTING MOVE MEDIA BY DATE TESTS"
  
  # Check if required dependencies are installed
  if ! command -v exiftool &>/dev/null; then
    print_error "exiftool is required for these tests. Please install it first."
    exit 1
  fi
  
  setup_test_env
  run_tests
  
  print_header "ALL MOVE MEDIA BY DATE TESTS COMPLETED"
}

main "$@" 