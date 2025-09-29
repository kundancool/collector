#!/bin/bash

# Build script - Build release binary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_build "Building release binary..."
check_rust

print_info "Compiling in release mode..."
cargo build --release

if [ -f "target/release/$BINARY_NAME" ]; then
    print_success "Build completed successfully!"
    print_info "Binary location: target/release/$BINARY_NAME"
    ls -lh "target/release/$BINARY_NAME"
else
    print_error "Build failed - binary not found"
    exit 1
fi

print_info "Running tests..."
cargo test
print_success "All tests passed!"