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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/move_photos_by_date.sh"

# Test directory structure
TEST_DIR="${SCRIPT_DIR}/tests/test_photos"
SOURCE_DIR="${TEST_DIR}/source"
TARGET_DIR="${TEST_DIR}/target"

# Function to print error and exit
print_error_and_exit() {
    local message="$1"
    echo -e "${RED}$message${NC}"
    exit 1
}

# Check if the script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
    print_error_and_exit "Error: Script $SCRIPT_PATH not found"
fi

# Check if exiftool is installed
if ! command -v exiftool &>/dev/null; then
    print_error_and_exit "Error: exiftool is not installed. Please install it with: sudo apt-get install libimage-exiftool-perl"
fi

# Check if ImageMagick is installed
if ! command -v convert &>/dev/null; then
    print_error_and_exit "Error: ImageMagick is not installed. Please install it with: sudo apt-get install imagemagick"
fi

# Cleanup existing test files and directories
echo -e "${YELLOW}Cleaning up existing test files...${NC}"
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

    echo "Created test image: $file_path with date: $date_str"
}

# Create test images with different dates
echo -e "${YELLOW}Creating test images...${NC}"

create_test_image "$SOURCE_DIR/photo1.jpg" "2023:05:15 10:30:00"
create_test_image "$SOURCE_DIR/photo2.jpg" "2024:11:20 15:45:00"
create_test_image "$SOURCE_DIR/subdir/photo3.jpg" "2025:06:25 08:15:00"

# Image without EXIF date (will use file modification time)
convert -size 10x10 xc:blue "$SOURCE_DIR/photo_no_exif.jpg"
touch -t 202203101200 "$SOURCE_DIR/photo_no_exif.jpg"
echo "Created test image: $SOURCE_DIR/photo_no_exif.jpg with modification time: 2022-03-10"

# Run tests
echo -e "\n${YELLOW}Running tests...${NC}"

# Function to check if files exist in target directory
check_files_in_target() {
    local files=("$@")
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}✗ Test failed: $file not found in expected location${NC}"
            exit 1
        fi
    done
}

# Test 1: Move a single photo
echo -e "\n${YELLOW}Test 1: Moving a single photo${NC}"
"$SCRIPT_PATH" "$SOURCE_DIR/photo1.jpg" "$TARGET_DIR"
check_files_in_target "$TARGET_DIR/2023/05/photo1.jpg"
echo -e "${GREEN}✓ Test 1 passed: Photo moved to correct year/month directory${NC}"

# Recreate photo1.jpg for next tests
create_test_image "$SOURCE_DIR/photo1.jpg" "2023:05:15 10:30:00"

# Test 2: Move photos from directory (non-recursive)
echo -e "\n${YELLOW}Test 2: Moving photos from directory (non-recursive)${NC}"
"$SCRIPT_PATH" "$SOURCE_DIR" "$TARGET_DIR"
check_files_in_target \
    "$TARGET_DIR/2023/05/photo1.jpg" \
    "$TARGET_DIR/2024/11/photo2.jpg" \
    "$TARGET_DIR/2022/03/photo_no_exif.jpg"
echo -e "${GREEN}✓ Test 2 passed: Photos moved to correct year/month directories${NC}"

# Test 3: Move photos recursively
echo -e "\n${YELLOW}Test 3: Moving photos recursively${NC}"
"$SCRIPT_PATH" --recursive "$SOURCE_DIR" "$TARGET_DIR"
check_files_in_target "$TARGET_DIR/2025/06/photo3.jpg"
echo -e "${GREEN}✓ Test 3 passed: Photo from subdirectory moved to correct year/month directory${NC}"

# Test 4: Filename conflict resolution
echo -e "\n${YELLOW}Test 4: Testing filename conflict resolution${NC}"
create_test_image "$SOURCE_DIR/conflict_photo.jpg" "2023:05:15 10:30:00"
"$SCRIPT_PATH" "$SOURCE_DIR/conflict_photo.jpg" "$TARGET_DIR"

create_test_image "$SOURCE_DIR/conflict_photo.jpg" "2023:05:15 10:30:00"
"$SCRIPT_PATH" "$SOURCE_DIR/conflict_photo.jpg" "$TARGET_DIR"

# Check if both files exist with different names
count=$(ls -1 "$TARGET_DIR/2023/05/conflict_photo"* | wc -l)
if [[ $count -eq 2 ]]; then
    echo -e "${GREEN}✓ Test 4 passed: Filename conflict resolved correctly${NC}"
else
    echo -e "${RED}✗ Test 4 failed: Filename conflict not resolved correctly${NC}"
    exit 1
fi

# All tests passed
echo -e "\n${GREEN}All tests passed successfully!${NC}"
echo -e "${YELLOW}Test files are in $TEST_DIR${NC}"
echo -e "${YELLOW}You can remove them with: rm -rf $TEST_DIR${NC}"

exit 0
