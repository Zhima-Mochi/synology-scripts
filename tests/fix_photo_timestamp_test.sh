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

# Add a helper to check if mtime was NOT changed
check_mtime_unchanged() {
    local file="$1"
    local expected_mtime_ts="$2"
    local file_ts
    file_ts=$(stat -c %Y "$file")

    if [[ "$file_ts" -eq "$expected_mtime_ts" ]]; then
        print_success "✓ File $(basename "$file") was correctly skipped (mtime unchanged)."
        return 0
    else
        print_error "✗ File $(basename "$file") was incorrectly processed (mtime changed)."
        print_error "  Expected mtime: $(date -d "@${expected_mtime_ts}")"
        print_error "  Actual mtime:   $(date -d "@${file_ts}")"
        return 1
    fi
}

# ----- Test Cases -----

# Test 1: Basic functionality - process all files
run_test_basic_functionality() {
    print_info "\nTest 1: Basic functionality - process all files"
    "$SCRIPT_PATH" "$SOURCE_DIR"

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
    reset_test_files
    
    local mtime1=$(date -d "2022-01-01" +%s)
    local mtime2=$(date -d "2022-04-01" +%s)
    local mtime3=$(date -d "2023-04-01" +%s)
    touch -d "@$mtime1" "${SOURCE_DIR}/${TS1}.jpg" # before filter -> skip
    touch -d "@$mtime2" "${SOURCE_DIR}/${TS2}.jpg" # after filter -> process
    touch -d "@$mtime3" "${SOURCE_DIR}/${TS3}.jpg" # after filter -> process

    print_info "\nTest 2: Filter by after time (mtime)"
    local after_date="2022-03-01"
    "$SCRIPT_PATH" "$SOURCE_DIR" -a "$after_date"

    local errors=0
    check_mtime_unchanged "${SOURCE_DIR}/${TS1}.jpg" "$mtime1" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS3}.jpg" "$TS3" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 2 passed: After time filter working correctly"
    else
        print_error "✗ Test 2 failed: $errors errors detected"
    fi
    return $errors
}

# Test 3: Before time filter
run_test_before_time() {
    reset_test_files

    local mtime2=$(date -d "2022-08-01" +%s)
    local mtime3=$(date -d "2023-04-01" +%s)
    touch -d "@$mtime2" "${SOURCE_DIR}/${TS2}.jpg" # before filter -> process
    touch -d "@$mtime3" "${SOURCE_DIR}/${TS3}.jpg" # after filter -> skip
    
    print_info "\nTest 3: Filter by before time (mtime)"
    local before_date="2023-01-01"
    "$SCRIPT_PATH" "$SOURCE_DIR" -b "$before_date"

    local errors=0
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_mtime_unchanged "${SOURCE_DIR}/${TS3}.jpg" "$mtime3" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 3 passed: Before time filter working correctly"
    else
        print_error "✗ Test 3 failed: $errors errors detected"
    fi
    return $errors
}

# Test 4: Time range filter (both before and after)
run_test_time_range() {
    reset_test_files

    local mtime1=$(date -d "2021-12-31" +%s)
    local mtime2=$(date -d "2022-06-15" +%s)
    local mtime3=$(date -d "2023-01-01" +%s)
    touch -d "@$mtime1" "${SOURCE_DIR}/${TS1}.jpg" # before range -> skip
    touch -d "@$mtime2" "${SOURCE_DIR}/${TS2}.jpg" # in range -> process
    touch -d "@$mtime3" "${SOURCE_DIR}/${TS3}.jpg" # after range -> skip

    print_info "\nTest 4: Filter by time range (mtime)"
    local after_date="2022-01-01"
    local before_date="2022-12-31"
    "$SCRIPT_PATH" "$SOURCE_DIR" -a "$after_date" -b "$before_date"

    local errors=0
    check_mtime_unchanged "${SOURCE_DIR}/${TS1}.jpg" "$mtime1" || ((errors++))
    check_timestamp "${SOURCE_DIR}/${TS2}.jpg" "$TS2" || ((errors++))
    check_mtime_unchanged "${SOURCE_DIR}/${TS3}.jpg" "$mtime3" || ((errors++))

    if [[ $errors -eq 0 ]]; then
        print_success "✓ Test 4 passed: Time range filter working correctly"
    else
        print_error "✗ Test 4 failed: $errors errors detected"
    fi
    return $errors
}

# Test 5: Recursive mode
run_test_recursive() {
    # Reset test files and create a subdirectory with test files
    reset_test_files
    mkdir -p "${SOURCE_DIR}/subdir"
    convert -size 10x10 xc:white "${SOURCE_DIR}/subdir/${TS1}.jpg"
    touch "${SOURCE_DIR}/subdir/${TS1}.jpg"

    print_info "\nTest 5: Test recursive mode"
    "$SCRIPT_PATH" "$SOURCE_DIR" -r

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
