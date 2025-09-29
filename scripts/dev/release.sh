#!/bin/bash

# Release mode script - Build and run in release mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Building and running in release mode..."
check_rust
pre_run_checks

print_info "Building $BINARY_NAME (release mode)..."
cargo build --release

print_success "Starting server at http://$HOST:$PORT"
print_info "Press Ctrl+C to stop the server"

exec ./target/release/$BINARY_NAME