#!/bin/bash

# Status script - Show project and system status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

detect_init_system() {
    if command -v systemctl &> /dev/null && [ -d "/etc/systemd/system" ]; then
        echo "systemd"
    elif command -v rc-service &> /dev/null && [ -d "/etc/init.d" ]; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

check_kafka() {
    local kafka_host=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f1)
    local kafka_port=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f2 | cut -d, -f1)

    if ! nc -z "$kafka_host" "$kafka_port" 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

print_info "Project Status:"
echo ""

# Rust installation
if command -v cargo &> /dev/null; then
    print_success "✓ Rust: $(cargo --version)"
else
    print_error "✗ Rust: Not installed"
fi

# Configuration files
if [ -f "$CONFIG_FILE" ]; then
    print_success "✓ Config: $CONFIG_FILE exists"
else
    print_warning "⚠ Config: $CONFIG_FILE missing"
fi

if [ -f ".env" ]; then
    print_success "✓ Environment: .env exists"
else
    print_warning "⚠ Environment: .env missing"
fi

# Build status
if [ -f "target/release/$BINARY_NAME" ]; then
    binary_size=$(ls -lah "target/release/$BINARY_NAME" | awk '{print $5}')
    print_success "✓ Binary: target/release/$BINARY_NAME ($binary_size)"
else
    print_warning "⚠ Binary: Not built"
fi

# Kafka connectivity
print_info "Checking Kafka connectivity..."
if check_kafka; then
    print_success "✓ Kafka: Accessible on $KAFKA_BOOTSTRAP_SERVERS"
else
    print_warning "⚠ Kafka: Not accessible on $KAFKA_BOOTSTRAP_SERVERS"
fi

# System installation
if [ -f "$INSTALL_BIN_DIR/$BINARY_NAME" ]; then
    print_success "✓ System Install: $INSTALL_BIN_DIR/$BINARY_NAME"
else
    print_warning "⚠ System Install: Not installed"
fi

# Service status
init_system=$(detect_init_system)
case "$init_system" in
    "systemd")
        if systemctl is-enabled $BINARY_NAME &>/dev/null; then
            status=$(systemctl is-active $BINARY_NAME)
            print_success "✓ Service: $BINARY_NAME ($status)"
        else
            print_warning "⚠ Service: Not installed/enabled"
        fi
        ;;
    "openrc")
        if rc-service $BINARY_NAME status &>/dev/null; then
            print_success "✓ Service: $BINARY_NAME (OpenRC)"
        else
            print_warning "⚠ Service: Not installed"
        fi
        ;;
    *)
        print_warning "⚠ Service: Unknown init system"
        ;;
esac