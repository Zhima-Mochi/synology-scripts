#!/usr/bin/env bash
# Test script for fix_media_timestamp.sh

set -euo pipefail
IFS=$'\n\t'

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_OUTPUT_DIR="$SCRIPT_DIR/output/media"

# Source utility functions
source "$ROOT_DIR/utils/basic_utils.sh"
source "$ROOT_DIR/utils/file_utils.sh"

# Initialize test environment
setup_test_env() {
  print_header "Setting up test environment for fix_media_timestamp tests"
  
  # Create test output directory if it doesn't exist
  mkdir -p "$TEST_OUTPUT_DIR"
  
  # Remove any existing test files
  rm -rf "$TEST_OUTPUT_DIR"/*
  
  # Create test media files with Unix timestamps as filenames
  # Photos
  create_test_image "$TEST_OUTPUT_DIR/1609459200.jpg" "2019:01:01 12:00:00"  # Jan 1, 2021
  create_test_image "$TEST_OUTPUT_DIR/1612137600.jpg" "2020:01:01 12:00:00"  # Feb 1, 2021
  create_test_image "$TEST_OUTPUT_DIR/1614556800.jpg" "2018:01:01 12:00:00"  # Mar 1, 2021
  
  # Videos - with millisecond timestamps (13 digits)
  if command -v ffmpeg &>/dev/null; then
    create_test_video "$TEST_OUTPUT_DIR/1617235200000.mp4" "2017:01:01 12:00:00"  # Apr 1, 2021
    create_test_video "$TEST_OUTPUT_DIR/1619827200000.mp4" "2016:01:01 12:00:00"  # May 1, 2021
  else
    print_warning "ffmpeg not found, skipping video test file creation"
    # Create dummy text files instead for testing
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/1617235200000.mp4"
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/1619827200000.mp4"
  fi
  
  # Create a directory to test recursive option
  mkdir -p "$TEST_OUTPUT_DIR/subdir"
  create_test_image "$TEST_OUTPUT_DIR/subdir/1622505600.jpg" "2015:01:01 12:00:00"  # Jun 1, 2021
  if command -v ffmpeg &>/dev/null; then
    create_test_video "$TEST_OUTPUT_DIR/subdir/1625097600000.mp4" "2014:01:01 12:00:00"  # Jul 1, 2021
  else
    echo "Dummy video file" > "$TEST_OUTPUT_DIR/subdir/1625097600000.mp4"
  fi
  
  # Create a non-matching file (not a Unix timestamp)
  create_test_image "$TEST_OUTPUT_DIR/photo_vacation.jpg"
  
  print_success "Test environment setup complete"
}

# Test the fix_media_timestamp script with various options
run_tests() {
  print_header "Running fix_media_timestamp tests"
  
  cd "$ROOT_DIR"
  
  # Test 1: Fix timestamps on all media files in directory (non-recursive)
  print_info "Test 1: Fix timestamps for all media files in directory"
  ./media/fix_media_timestamp.sh "$TEST_OUTPUT_DIR"
  
  # Test 2: Fix timestamps with the recursive option
  print_info "Test 2: Fix timestamps recursively"
  ./media/fix_media_timestamp.sh -r "$TEST_OUTPUT_DIR"
  
  # Test 3: Fix timestamps with after-time filter
  print_info "Test 3: Fix timestamps with after-time filter (after Feb 15, 2021)"
  ./media/fix_media_timestamp.sh -a "2021-02-15" "$TEST_OUTPUT_DIR"
  
  # Test 4: Fix timestamps with before-time filter
  print_info "Test 4: Fix timestamps with before-time filter (before Feb 15, 2021)"
  ./media/fix_media_timestamp.sh -b "2021-02-15" "$TEST_OUTPUT_DIR"
  
  # Test 5: Fix timestamps with both before and after filters
  print_info "Test 5: Fix timestamps with both before and after filters (Jan 15 - Mar 15, 2021)"
  ./media/fix_media_timestamp.sh -a "2021-01-15" -b "2021-03-15" "$TEST_OUTPUT_DIR"
  
  # Test 6: Fix timestamps and move media files to target directory
  print_info "Test 6: Fix timestamps and move media files to target directory"
  
  # Reset the test environment for clean test
  setup_test_env
  
  # Create a dedicated target directory for this test
  local move_target_dir="$TEST_OUTPUT_DIR/moved_media"
  mkdir -p "$move_target_dir"
  
  # Run the command with the -m option
  print_info "Running fix_media_timestamp with -m option"
  ./media/fix_media_timestamp.sh -m "$move_target_dir" "$TEST_OUTPUT_DIR"
  
  # Verify that files were moved and organized by date
  print_info "Verifying moved files in target directory structure"
  if find "$move_target_dir" -type f | grep -q .; then
    print_success "Files found in target directory - move operation succeeded"
    # Show year/month directory structure created by the move operation
    echo "Directory structure created:"
    find "$move_target_dir" -type d | sort
    # List moved files
    echo "Files organized by date:"
    find "$move_target_dir" -type f | sort
  else
    print_error "No files found in target directory - move operation failed"
  fi
  
  # Test 7: Fix timestamps and move media files with recursive option
  print_info "Test 7: Fix timestamps and move media files with recursive option"
  
  # Reset the test environment for clean test
  setup_test_env
  
  # Create a dedicated target directory for this test
  local move_target_dir_recursive="$TEST_OUTPUT_DIR/moved_media_recursive"
  mkdir -p "$move_target_dir_recursive"
  
  # Run the command with both -r and -m options
  print_info "Running fix_media_timestamp with -r and -m options"
  ./media/fix_media_timestamp.sh -r -m "$move_target_dir_recursive" "$TEST_OUTPUT_DIR"
  
  # Verify that files from subdirectories were also moved
  print_info "Verifying files from subdirectories were moved"
  if find "$move_target_dir_recursive" -type f | grep -q .; then
    print_success "Files found in target directory - recursive move operation succeeded"
    # Count number of files moved
    local file_count=$(find "$move_target_dir_recursive" -type f | wc -l)
    echo "Total files moved: $file_count"
    # Show directory structure
    echo "Directory structure created:"
    find "$move_target_dir_recursive" -type d | sort
  else
    print_error "No files found in target directory - recursive move operation failed"
  fi
  
  print_success "All tests executed successfully"
}

# Main function
main() {
  print_header "STARTING FIX MEDIA TIMESTAMP TESTS"
  
  # Check if required dependencies are installed
  if ! command -v exiftool &>/dev/null; then
    print_error "exiftool is required for these tests. Please install it first."
    exit 1
  fi
  
  setup_test_env
  run_tests
  
  print_header "ALL FIX MEDIA TIMESTAMP TESTS COMPLETED"
}

main "$@" 