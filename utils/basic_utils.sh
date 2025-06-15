#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Basic Utilities
# ---------------------------------------------------------------------------
# Provides basic utility functions for shell scripts.
#
# Usage:
#   source this_script.sh
# ---------------------------------------------------------------------------

# Source logger utilities
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Check if a command exists, and exit if it's not found.
# Usage: require_cmd "command_name"
require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' command not found"
} 