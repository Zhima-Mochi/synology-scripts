#!/bin/bash

# ---------------------------------------------------------------------------
#  Test Script for move_photos_by_date.sh
# ---------------------------------------------------------------------------
#  This script tests the functionality of the photo date organizer script
#  by creating test photos with different dates and verifying correct movement.
#
#  Usage:
#    ./test_move_photos.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/file_utils.sh"

# Script paths
SCRIPT_PATH="${SCRIPT_DIR}/../photos/move_photos_by_date.sh"

# Test directory structure
TEST_DIR="${SCRIPT_DIR}/output/test_photos"
SOURCE_DIR="${TEST_DIR}/source"
TARGET_DIR="${TEST_DIR}/target"

# Function to print error and exit
print_error_and_exit() {
    print_error "$1"
    exit 1
}

# Check if the script exists
[[ ! -f "$SCRIPT_PATH" ]] && print_error_and_exit "Error: Script $SCRIPT_PATH not found"

# Check dependencies
require_cmd exiftool
require_cmd convert

# Cleanup existing test files and directories
print_info "Cleaning up existing test files..."
rm -rf "$TEST_DIR"
mkdir -p "$SOURCE_DIR"
mkdir -p "$TARGET_DIR"
mkdir -p "$SOURCE_DIR/subdir"

# Function to create a test image with EXIF date
create_test_image() {
    local file_path="$1"
    local date_str="$2"

    # Create a simple 10x10 JPEG image
    convert -size 10x10 xc:white "$file_path"

    # Set the EXIF date
    exiftool -overwrite_original "-DateTimeOriginal=$date_str" "$file_path" >/dev/null

    print_info "Created test image: $file_path with date: $date_str"
}

# Create test images with different dates
print_info "Creating test images..."

create_test_image "$SOURCE_DIR/photo1.jpg" "2023:05:15 10:30:00"
create_test_image "$SOURCE_DIR/photo2.jpg" "2024:11:20 15:45:00"
create_test_image "$SOURCE_DIR/subdir/photo3.jpg" "2025:06:25 08:15:00"

# Image without EXIF date (will use file modification time)
create_test_image "$SOURCE_DIR/photo_no_exif.jpg" ""
touch -t 202203101200 "$SOURCE_DIR/photo_no_exif.jpg"
print_info "Created test image: $SOURCE_DIR/photo_no_exif.jpg with modification time: 2022-03-10"

# Run tests
print_info "\nRunning tests..."

# Function to check if files exist in target directory
check_files_in_target() {
    local files=("$@")
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "✗ Test failed: $file not found in expected location"
            exit 1
        fi
    done
}

# Test 1: Move a single photo
print_info "\nTest 1: Moving a single photo"
"$SCRIPT_PATH" "$SOURCE_DIR/photo1.jpg" "$TARGET_DIR"
check_files_in_target "$TARGET_DIR/2023/05/photo1.jpg"
print_success "✓ Test 1 passed: Photo moved to correct year/month directory"

# Recreate photo1.jpg for next tests
create_test_image "$SOURCE_DIR/photo1.jpg" "2023:05:15 10:30:00"

# Test 2: Move photos from directory (non-recursive)
print_info "\nTest 2: Moving photos from directory (non-recursive)"
"$SCRIPT_PATH" "$SOURCE_DIR" "$TARGET_DIR"
check_files_in_target \
    "$TARGET_DIR/2023/05/photo1.jpg" \
    "$TARGET_DIR/2024/11/photo2.jpg" \
    "$TARGET_DIR/2022/03/photo_no_exif.jpg"
print_success "✓ Test 2 passed: Photos moved to correct year/month directories"

# Test 3: Move photos recursively
print_info "\nTest 3: Moving photos recursively"
"$SCRIPT_PATH" --recursive "$SOURCE_DIR" "$TARGET_DIR"
check_files_in_target "$TARGET_DIR/2025/06/photo3.jpg"
print_success "✓ Test 3 passed: Photo from subdirectory moved to correct year/month directory"

# Test 4: Filename conflict resolution
print_info "\nTest 4: Testing filename conflict resolution"
create_test_image "$SOURCE_DIR/conflict_photo.jpg" "2023:05:15 10:30:00"
"$SCRIPT_PATH" "$SOURCE_DIR/conflict_photo.jpg" "$TARGET_DIR"

create_test_image "$SOURCE_DIR/conflict_photo.jpg" "2023:05:15 10:30:00"
"$SCRIPT_PATH" "$SOURCE_DIR/conflict_photo.jpg" "$TARGET_DIR"

# Check if both files exist with different names
count=$(ls -1 "$TARGET_DIR/2023/05/conflict_photo"* | wc -l)
if [[ $count -eq 2 ]]; then
    print_success "✓ Test 4 passed: Filename conflict resolved correctly"
else
    print_error "✗ Test 4 failed: Filename conflict not resolved correctly"
    exit 1
fi

# All tests passed
print_success "\nAll tests passed successfully!"
print_info "Test files are in $TEST_DIR"
print_info "You can remove them with: rm -rf $TEST_DIR"

exit 0
