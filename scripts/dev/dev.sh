#!/bin/bash

# Development mode script - Build and run in development mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Building and running in development mode..."
check_rust
pre_run_checks

print_info "Building $BINARY_NAME (debug mode)..."
cargo build

print_success "Starting server at http://$HOST:$PORT"
print_info "Press Ctrl+C to stop the server"
print_info "Health check: curl http://$HOST:$PORT/health"

exec cargo run