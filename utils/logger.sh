#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Logger Utilities
# ---------------------------------------------------------------------------
# Provides colored logging functions for shell scripts.
#
# Usage:
#   source this_script.sh
#   print_info "This is an info message."
#   print_success "Operation completed successfully."
#   print_error "An error occurred."
# ---------------------------------------------------------------------------

# ------ Terminal Colors ------
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m' # No Color

# ------ Logging Functions ------

# Print a message in yellow.
# Usage: print_info "Your message"
print_info() {
  printf "${YELLOW}%s${NC}\n" "$1"
}

# Print a message in green.
# Usage: print_success "Your message"
print_success() {
  printf "${GREEN}%s${NC}\n" "$1"
}

# Print a message in red to stderr.
# Usage: print_error "Your message"
print_error() {
  printf "${RED}%s${NC}\n" "$1" >&2
}

# Print an error message and exit with a non-zero status.
# Usage: die "Fatal error"
die() {
  print_error "$1"
  exit 1
}
