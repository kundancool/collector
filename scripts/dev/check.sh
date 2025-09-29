#!/bin/bash

# Code quality check script - Run all code checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Running comprehensive code checks..."
check_rust

print_info "Running cargo check..."
cargo check

print_info "Running cargo clippy..."
cargo clippy -- -D warnings

print_info "Checking formatting..."
cargo fmt -- --check

print_info "Running tests..."
cargo test

print_success "All checks passed!"