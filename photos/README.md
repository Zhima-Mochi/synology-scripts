# Photo Management Scripts

This directory contains scripts for managing photos, fixing timestamps, and organizing files by date.

## Scripts

- `fix_photo_timestamp.sh`: Updates photo timestamps using the filename (assumes Unix timestamp as filename)
- `move_photos_by_date.sh`: Moves photos into a year/month directory structure based on EXIF data

## Shared Utilities

These scripts use shared utility functions from `../utils/photo_utils.sh` to eliminate code duplication.

The shared utilities include:
- Color output formatting
- Command validation
- Error handling
- File/directory manipulation helpers
- EXIF metadata extraction and manipulation
- Testing utilities

## Running Tests

Each script has a corresponding test script in the root `tests` directory to verify functionality:

```bash
../tests/fix_photo_timestamp_test.sh
../tests/move_photos_by_date_test.sh
```
