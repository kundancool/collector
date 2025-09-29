#!/bin/bash

# Deploy script - Complete deployment pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_build "Running complete deployment pipeline..."

# Clean first
$SCRIPT_DIR/../build/clean.sh

# Build
$SCRIPT_DIR/../build/build.sh

# Install
$SCRIPT_DIR/install.sh

# Create service
$SCRIPT_DIR/service.sh

print_success "Deployment completed!"