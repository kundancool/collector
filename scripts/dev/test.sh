#!/bin/bash

# Unit test script - Run unit tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_dev "Running unit tests..."
check_rust

cargo test