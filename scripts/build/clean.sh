#!/bin/bash

# Clean script - Clean all build artifacts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Cleaning build artifacts..."
check_rust

print_info "Cleaning target directory..."
cargo clean

if [ -d "$DIST_DIR" ]; then
    print_info "Cleaning $DIST_DIR directory..."
    rm -rf "$DIST_DIR"
fi

print_success "Cleanup completed"