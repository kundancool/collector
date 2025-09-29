#!/bin/bash

# Watch mode script - Run with file watching for hot reload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Running with file watching..."

if ! command -v cargo-watch &> /dev/null; then
    print_error "cargo-watch is not installed."
    print_info "Install it with: cargo install cargo-watch"
    exit 1
fi

check_rust
pre_run_checks

print_success "Starting with hot reload..."
print_info "Server will restart automatically when files change"
print_info "Press Ctrl+C to stop"

exec cargo watch -x run