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

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/file_utils.sh"

# Script paths
SCRIPT_PATH="${SCRIPT_DIR}/../photos/fix_photo_timestamp.sh"

# Test directory structure
TEST_DIR="${SCRIPT_DIR}/output/test_timestamp_photos"
SOURCE_DIR="${TEST_DIR}/source"

# ----- Helper Functions -----

# Check necessary dependencies
check_dependencies() {
    # Check if the main script exists
    [[ ! -f "$SCRIPT_PATH" ]] && die "Error: Script $SCRIPT_PATH not found"

    # Check if ImageMagick is installed
    require_cmd convert
}

# Prepare test environment
prepare_test_environment() {
    print_info "Creating test directories..."
    rm -rf "$TEST_DIR"
    mkdir -p "$SOURCE_DIR"
    print_info "Test directory created at: $SOURCE_DIR"
}

# Create test images for the timestamp test
create_test_images() {
    print_info "Creating test images..."

    # Create timestamps for testing
    # 2022-01-15 12:30:45
    export TS1=1642249845
    # 2022-06-20 08:15:30
    export TS2=1655710530
    # 2023-03-10 18:45:20
    export TS3=1678469120
    # 2021-12-25 00:00:00 (for testing time range filters)
    export TS4=1640390400
    # 2023-07-01 00:00:00 (for testing time range filters)
    export TS5=1688169600

    # Create test images with timestamp filenames
    convert -size 10x10 xc:white "${SOURCE_DIR}/${TS1}.jpg"
    convert -size 10x10 xc:white "${SOURCE_DIR}/${TS2}.jpg"
    convert -size 10x10 xc:white "${SOURCE_DIR}/${TS3}.jpg"
    convert -size 10x10 xc:white "${SOURCE_DIR}/${TS4}.jpg"
    convert -size 10x10 xc:white "${SOURCE_DIR}/${TS5}.jpg"
    
    print_info "Created timestamp images in ${SOURCE_DIR}"

    # Create a file with non-timestamp filename for testing skipping
    convert -size 10x10 xc:white "${SOURCE_DIR}/not_a_timestamp.jpg"
    print_info "Created test image: ${SOURCE_DIR}/not_a_timestamp.jpg (should be skipped)"

    # Touch all files to ensure they have a consistent timestamp different from the filename
    touch "${SOURCE_DIR}"/*.jpg
    print_info "Reset file timestamps"
}

# Reset test files
reset_test_files() {
    print_info "Resetting test environment..."
    rm -rf "$SOURCE_DIR"
    mkdir -p "$SOURCE_DIR"
    create_test_images
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

    # Verify non-timestamp file was skipped
    check_file_skipped "${SOURCE_DIR}/not_a_timestamp.jpg" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 1 passed: Basic functionality working correctly"
        return 0
    else
        print_error "✗ Test 1 failed: $errors errors detected"
        return 1
    fi
}

# Test 2: After time filter
run_test_after_time() {
    # Reset test files
    reset_test_files

    # Set specific modification times for testing
    touch -d "2022-01-01" "${SOURCE_DIR}/${TS1}.jpg" # mtime before filter
    touch -d "2022-04-01" "${SOURCE_DIR}/${TS2}.jpg" # mtime after filter
    touch -d "2023-04-01" "${SOURCE_DIR}/${TS3}.jpg" # mtime after filter

    print_info "\nTest 2: Filter by after time"
    # Process only files with modification time after 2022-03-01
    local after_date="2022-03-01"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -a "$after_date"

    local errors=0
    
    # TS1 should NOT be processed. Its mtime should be the one we set.
    local ts1_mtime=$(stat -c %Y "${SOURCE_DIR}/${TS1}.jpg")
    local expected_ts1_mtime=$(date -d "2022-01-01" +%s)
    if [[ $ts1_mtime -eq $expected_ts1_mtime ]]; then
        print_success "✓ File ${TS1}.jpg correctly not processed."
    else
        print_error "✗ File ${TS1}.jpg was incorrectly processed."
        ((errors++))
    fi

    # TS2 and TS3 should BE processed. Their mtimes should match their filename timestamps.
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS3}.jpg" "$TS3" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 2 passed: After time filter working correctly"
        return 0
    else
        print_error "✗ Test 2 failed: $errors errors detected"
        return 1
    fi
}

# Test 3: Before time filter
run_test_before_time() {
    # Reset test files
    reset_test_files

    # Set specific modification times for testing
    touch -d "2022-01-01" "${SOURCE_DIR}/${TS2}.jpg" # mtime before filter
    touch -d "2023-04-01" "${SOURCE_DIR}/${TS3}.jpg" # mtime after filter

    print_info "\nTest 3: Filter by before time"
    # Process only files with modification time before 2023-01-01
    local before_date="2023-01-01"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -b "$before_date"

    local errors=0

    # TS2 should BE processed
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))

    # TS3 should NOT be processed
    local ts3_mtime=$(stat -c %Y "${SOURCE_DIR}/${TS3}.jpg")
    local expected_ts3_mtime=$(date -d "2023-04-01" +%s)
    if [[ $ts3_mtime -eq $expected_ts3_mtime ]]; then
        print_success "✓ File ${TS3}.jpg correctly not processed."
    else
        print_error "✗ File ${TS3}.jpg was incorrectly processed."
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 3 passed: Before time filter working correctly"
        return 0
    else
        print_error "✗ Test 3 failed: $errors errors detected"
        return 1
    fi
}

# Test 4: Time range filter (both before and after)
run_test_time_range() {
    # Reset test files
    reset_test_files

    # Set specific modification times
    touch -d "2021-01-01" "${SOURCE_DIR}/${TS1}.jpg" # a year before
    touch -d "2022-06-01" "${SOURCE_DIR}/${TS2}.jpg" # within range
    touch -d "2023-01-01" "${SOURCE_DIR}/${TS3}.jpg" # a year after

    print_info "\nTest 4: Filter by time range"
    # Process only files with modification time between 2022-01-01 and 2022-12-31
    local after_date="2022-01-01"
    local before_date="2022-12-31"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -a "$after_date" -b "$before_date"

    local errors=0
    
    # Only TS2 should be processed
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))

    # TS1 should NOT be processed
    local ts1_mtime=$(stat -c %Y "${SOURCE_DIR}/${TS1}.jpg")
    local expected_ts1_mtime=$(date -d "2021-01-01" +%s)
    if [[ $ts1_mtime -eq $expected_ts1_mtime ]]; then
        print_success "✓ File ${TS1}.jpg correctly not processed."
    else
        print_error "✗ File ${TS1}.jpg was incorrectly processed."
        ((errors++))
    fi

    # TS3 should NOT be processed
    local ts3_mtime=$(stat -c %Y "${SOURCE_DIR}/${TS3}.jpg")
    local expected_ts3_mtime=$(date -d "2023-01-01" +%s)
    if [[ $ts3_mtime -eq $expected_ts3_mtime ]]; then
        print_success "✓ File ${TS3}.jpg correctly not processed."
    else
        print_error "✗ File ${TS3}.jpg was incorrectly processed."
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 4 passed: Time range filter working correctly"
        return 0
    else
        print_error "✗ Test 4 failed: $errors errors detected"
        return 1
    fi
}

# Test 5: Recursive mode
run_test_recursive() {
    # Reset test files and create a subdirectory with test files
    reset_test_files
    mkdir -p "${SOURCE_DIR}/subdir"
    convert -size 10x10 xc:white "${SOURCE_DIR}/subdir/${TS1}.jpg"
    touch "${SOURCE_DIR}/subdir/${TS1}.jpg"

    print_info "\nTest 5: Test recursive mode"
    "$SCRIPT_PATH" -d "$SOURCE_DIR" -r

    local errors=0
    # Both root and subdir files should be processed
    check_timestamp "${SOURCE_DIR}/${TS1}.jpg" "$TS1" || ((errors++))
    check_timestamp "${SOURCE_DIR}/subdir/${TS1}.jpg" "$TS1" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 5 passed: Recursive mode working correctly"
        return 0
    else
        print_error "✗ Test 5 failed: $errors errors detected"
        return 1
    fi
}

# ----- Main Entry Point -----

main() {
    check_dependencies
    prepare_test_environment
    create_test_images

    local total_errors=0
    run_test_basic_functionality || ((total_errors++))
    run_test_after_time || ((total_errors++))
    run_test_before_time || ((total_errors++))
    run_test_time_range || ((total_errors++))
    run_test_recursive || ((total_errors++))

    if [[ $total_errors -eq 0 ]]; then
        print_success "\n✅ All tests passed successfully!"
    else
        print_error "\n❌ $total_errors test suites failed"
        exit 1
    fi
}

main "$@"
