#!/bin/bash

# ---------------------------------------------------------------------------
#  Test Script for fix_photo_timestamp.sh
# ---------------------------------------------------------------------------
#  This script tests the functionality of the photo timestamp fixing script
#  by creating test photos with different timestamps and verifying corrections.
#
#  Usage:
#    ./fix_photo_timestamp_test.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/fix_photo_timestamp.sh"

# Test directory structure
TEST_DIR="${SCRIPT_DIR}/tests/test_timestamp_photos"
SOURCE_DIR="${TEST_DIR}/source"

# ----- Helper Functions -----

# Print colored information
print_info() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check necessary dependencies
check_dependencies() {
    # Check if the main script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        print_error "Error: Script $SCRIPT_PATH not found"
        exit 1
    fi

    # Check if ImageMagick is installed
    if ! command -v convert &>/dev/null; then
        print_error "Error: ImageMagick is not installed. Please install it with:"
        echo "  sudo apt-get install imagemagick"
        exit 1
    fi
}

# Prepare test environment
prepare_test_environment() {
    print_info "Creating test directories..."
    rm -rf "$TEST_DIR"
    mkdir -p "$SOURCE_DIR"
}

# Create test image
create_test_image() {
    local timestamp="$1"
    local file_path="${SOURCE_DIR}/${timestamp}.jpg"

    # Create a simple 10x10 JPEG image
    convert -size 10x10 xc:white "$file_path"

    # Set the file's modification time to be different from the filename
    # (to verify the script corrects it)
    touch "$file_path"

    echo "Created test image: $file_path with filename timestamp: $(date -d @${timestamp})"
}

# Create all test images
create_test_images() {
    print_info "Creating test images..."

    # Create timestamps for testing
    # 2022-01-15 12:30:45
    TS1=1642249845
    # 2022-06-20 08:15:30
    TS2=1655710530
    # 2023-03-10 18:45:20
    TS3=1678469120
    # 2021-12-25 00:00:00 (for testing time range filters)
    TS4=1640390400
    # 2023-07-01 00:00:00 (for testing time range filters)
    TS5=1688169600

    create_test_image "$TS1"
    create_test_image "$TS2"
    create_test_image "$TS3"
    create_test_image "$TS4"
    create_test_image "$TS5"

    # Create a file with non-timestamp filename for testing skipping
    convert -size 10x10 xc:white "${SOURCE_DIR}/not_a_timestamp.jpg"
    echo "Created test image: ${SOURCE_DIR}/not_a_timestamp.jpg (should be skipped)"

    # Export timestamp variables for use in test functions
    export TS1 TS2 TS3 TS4 TS5
}

# Reset test files
reset_test_files() {
    rm -rf "$SOURCE_DIR"
    mkdir -p "$SOURCE_DIR"
    create_test_image "$TS1"
    create_test_image "$TS2"
    create_test_image "$TS3"
    create_test_image "$TS4"
    create_test_image "$TS5"
    convert -size 10x10 xc:white "${SOURCE_DIR}/not_a_timestamp.jpg"
}

# Check if file's timestamp matches expected value
check_timestamp() {
    local file="$1"
    local expected_ts="$2"
    local file_ts=$(stat -c %Y "$file")
    local expected_date=$(date -d @${expected_ts})
    local file_date=$(date -d @${file_ts})

    # Allow for 1 second difference due to processing time
    if [[ $((file_ts - expected_ts)) -ge -1 && $((file_ts - expected_ts)) -le 1 ]]; then
        print_success "✓ Timestamp correct for $(basename "$file"): ${file_date}"
        return 0
    else
        print_error "✗ Timestamp incorrect for $(basename "$file")"
        print_error "  Expected: ${expected_date}"
        print_error "  Actual: ${file_date}"
        return 1
    fi
}

# Check if file was correctly skipped (not modified)
check_file_skipped() {
    local file="$1"
    local reference="${SOURCE_DIR}/not_a_timestamp.jpg"

    if [[ $(stat -c %Y "$file") != $(stat -c %Y "$reference") ]]; then
        print_error "✗ File $(basename "$file") was incorrectly processed"
        return 1
    else
        print_success "✓ File $(basename "$file") was correctly skipped"
        return 0
    fi
}

# Check EXIF data if exiftool is available
check_exif() {
    if ! command -v exiftool &>/dev/null; then
        print_info "⚠ exiftool not installed, skipping EXIF verification"
        return 0
    fi

    local file="$1"
    local expected_ts="$2"
    local expected_date=$(date -d @${expected_ts} +"%Y:%m:%d %H:%M:%S")
    local exif_date=$(exiftool -s -s -s -DateTimeOriginal "$file")

    if [[ "$exif_date" == "$expected_date" ]]; then
        print_success "✓ EXIF DateTimeOriginal correct for $(basename "$file"): ${exif_date}"
        return 0
    else
        print_error "✗ EXIF DateTimeOriginal incorrect for $(basename "$file")"
        print_error "  Expected: ${expected_date}"
        print_error "  Actual: ${exif_date}"
        return 1
    fi
}

# ----- Test Cases -----

# Test 1: Basic functionality - process all files
run_test_basic_functionality() {
    print_info "\nTest 1: Basic functionality - process all files"
    "$SCRIPT_PATH" -d "$SOURCE_DIR"

    local errors=0
    # Verify timestamps were corrected
    check_timestamp "${SOURCE_DIR}/${TS1}.jpg" "$TS1" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS3}.jpg" "$TS3" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS4}.jpg" "$TS4" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS5}.jpg" "$TS5" || ((errors++))

    # Verify EXIF data if exiftool is available
    if command -v exiftool &>/dev/null; then
        check_exif "${SOURCE_DIR}/${TS1}.jpg" "$TS1" || ((errors++))
        check_exif "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
        check_exif "${SOURCE_DIR}/${TS3}.jpg" "$TS3" || ((errors++))
        check_exif "${SOURCE_DIR}/${TS4}.jpg" "$TS4" || ((errors++))
        check_exif "${SOURCE_DIR}/${TS5}.jpg" "$TS5" || ((errors++))
    fi

    return $errors
}

# Test 2: Time range filtering - after specific time
run_test_after_date() {
    print_info "\nTest 2: Time range filtering - after specific time"
    # Process only files after 2022-03-01
    local AFTER_DATE="2022-03-01"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -a "$AFTER_DATE"

    local errors=0

    check_timestamp "${SOURCE_DIR}/${TS1}.jpg" "$TS1" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS3}.jpg" "$TS3" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS4}.jpg" "$TS4" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS5}.jpg" "$TS5" || ((errors++))

    return $errors
}

# Test 3: Time range filtering - before specific time
run_test_before_date() {
    print_info "\nTest 3: Time range filtering - before specific time"
    # Process only files before 2022-03-01
    local BEFORE_DATE="2022-03-01"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -b "$BEFORE_DATE"

    local errors=0

    check_file_skipped "${SOURCE_DIR}/${TS1}.jpg" || ((errors++))
    check_file_skipped "${SOURCE_DIR}/${TS2}.jpg" || ((errors++))
    check_file_skipped "${SOURCE_DIR}/${TS3}.jpg" || ((errors++))
    check_file_skipped "${SOURCE_DIR}/${TS4}.jpg" || ((errors++))
    check_file_skipped "${SOURCE_DIR}/${TS5}.jpg" || ((errors++))

    return $errors
}

# ----- Main Function -----

main() {
    check_dependencies
    prepare_test_environment
    create_test_images

    print_info "\nRunning tests..."

    # Run all tests
    local total_errors=0

    # Test 1: Basic functionality
    run_test_basic_functionality
    total_errors=$((total_errors + $?))

    # Reset test files for next test
    reset_test_files

    # Test 2: Time range filtering - after specific time
    run_test_after_date
    total_errors=$((total_errors + $?))

    # Reset test files for next test
    reset_test_files

    # Test 3: Time range filtering - before specific time
    run_test_before_date
    total_errors=$((total_errors + $?))

    # Reset test files for next test
    reset_test_files

    # Test results
    if [[ $total_errors -eq 0 ]]; then
        print_success "\nAll tests passed successfully!"
    else
        print_error "\nTests completed with $total_errors errors."
        exit 1
    fi

    print_info "Test files are in $TEST_DIR"
    print_info "You can remove them with: rm -rf $TEST_DIR"
}

# Execute main function
main

exit 0
