#!/bin/bash

# Package script - Build and create distribution package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_build "Building and creating distribution package..."

# Run build script
$SCRIPT_DIR/build.sh

# Run dist script
$SCRIPT_DIR/dist.sh