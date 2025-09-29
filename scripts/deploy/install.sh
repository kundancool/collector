#!/bin/bash

# Install script - Install binary and configs system-wide

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_build "Installing $BINARY_NAME to system..."

# Check if binary exists
if [ ! -f "target/release/$BINARY_NAME" ]; then
    print_error "Binary not found. Please run 'build' first."
    exit 1
fi

# Check for sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Installation requires sudo privileges"
    echo "Please run: sudo $0"
    exit 1
fi

# Create directories
print_info "Creating installation directories..."
mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_CONFIG_DIR"

# Install binary
print_info "Installing binary to $INSTALL_BIN_DIR..."
cp "target/release/$BINARY_NAME" "$INSTALL_BIN_DIR/"
chmod +x "$INSTALL_BIN_DIR/$BINARY_NAME"
print_success "Binary installed to $INSTALL_BIN_DIR/$BINARY_NAME"

# Install configuration files
print_info "Installing configuration files to $INSTALL_CONFIG_DIR..."
if [ -f ".env.example" ]; then
    cp ".env.example" "$INSTALL_CONFIG_DIR/.env"
    print_success "Environment file installed"
fi
if [ -f "conf.example.yaml" ]; then
    cp "conf.example.yaml" "$INSTALL_CONFIG_DIR/conf.yaml"
    print_success "Configuration file installed"
fi

chmod 644 "$INSTALL_CONFIG_DIR"/* 2>/dev/null || true

print_success "Installation completed!"
print_info "Binary: $INSTALL_BIN_DIR/$BINARY_NAME"
print_info "Config: $INSTALL_CONFIG_DIR/"
print_warning "Please edit configuration files in $INSTALL_CONFIG_DIR/ before running"