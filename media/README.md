# Media Management Scripts

This directory contains scripts for managing media files (photos and videos), fixing timestamps, and organizing files by date.

## Scripts

- `fix_media_timestamp.sh`: Updates media file timestamps using the filename (assumes Unix timestamp as filename)
- `move_media_by_date.sh`: Moves media files into a year/month directory structure based on EXIF/metadata data

## Supported Media Formats

### Photos
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- BMP (.bmp)
- TIFF (.tiff)
- HEIC (.heic)
- RAW formats (.cr2, .arw, etc.)

### Videos
- MP4 (.mp4)
- MOV (.mov)
- AVI (.avi)
- MKV (.mkv)

## Shared Utilities

These scripts use shared utility functions from `../utils/file_utils.sh` to eliminate code duplication.

The shared utilities include:
- Color output formatting
- Command validation
- Error handling
- File/directory manipulation helpers
- EXIF/metadata extraction and manipulation
- Testing utilities

## Running Tests

Each script has a corresponding test script in the root `tests` directory to verify functionality:

```bash
../tests/fix_media_timestamp_test.sh
../tests/move_media_by_date_test.sh
``` 