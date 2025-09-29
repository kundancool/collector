#!/bin/bash

# Common utilities for all scripts
# This file should be sourced by other scripts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_dev() {
    echo -e "${CYAN}[DEV]${NC} $1"
}

print_build() {
    echo -e "${PURPLE}[BUILD]${NC} $1"
}

# Load configuration from .env file
load_env() {
    if [ -f ".env" ]; then
        export $(grep -v '^#' .env | xargs) 2>/dev/null || true
    elif [ -f ".env.example" ]; then
        print_warning "No .env file found, using .env.example as fallback"
        export $(grep -v '^#' .env.example | xargs) 2>/dev/null || true
    fi
}

# Set defaults if not defined in .env
set_defaults() {
    BINARY_NAME=${BINARY_NAME:-collector}
    CONFIG_FILE=${CONFIG_FILE:-conf.yaml}
    RUST_LOG=${RUST_LOG:-info}
    HOST=${HOST:-127.0.0.1}
    PORT=${PORT:-8080}
    KAFKA_BOOTSTRAP_SERVERS=${KAFKA_BOOTSTRAP_SERVERS:-localhost:9093}

    # Build/Install configuration
    INSTALL_PREFIX=${INSTALL_PREFIX:-/usr/local}
    INSTALL_BIN_DIR=${INSTALL_BIN_DIR:-$INSTALL_PREFIX/bin}
    INSTALL_CONFIG_DIR=${INSTALL_CONFIG_DIR:-$INSTALL_PREFIX/etc/$BINARY_NAME}
    DIST_DIR=${DIST_DIR:-dist}
    SERVICE_USER=${SERVICE_USER:-nobody}
    SERVICE_GROUP=${SERVICE_GROUP:-nogroup}
    SERVICE_DESCRIPTION=${SERVICE_DESCRIPTION:-Kafka Collector - HTTP to Kafka Bridge}
    SERVICE_DOCUMENTATION=${SERVICE_DOCUMENTATION:-https://github.com/kundan/kafka-rust}
}

# Initialize configuration
init_config() {
    load_env
    set_defaults
}

# Check if Rust is installed
check_rust() {
    if ! command -v cargo &> /dev/null; then
        print_error "Cargo is not installed. Please install Rust and Cargo first."
        echo "Visit: https://rustup.rs/"
        exit 1
    fi
}

# Check for configuration files
check_config() {
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "${CONFIG_FILE}.example" ]; then
        print_warning "No configuration file found!"
        print_info "Creating basic $CONFIG_FILE from template..."

        if [ -f "${CONFIG_FILE}.example" ]; then
            cp "${CONFIG_FILE}.example" "$CONFIG_FILE"
            print_success "Created $CONFIG_FILE from example"
        else
            # Create a basic config
            cat > "$CONFIG_FILE" << EOF
# Basic configuration for development
endpoints:
  - path: "/api/v1/events"
    kafka_topic: "user_events"
    kafka_partition: 0
  - path: "/api/v1/actions"
    kafka_topic: "user_actions"
    kafka_partition: 1
  - path: "/api/v1/logs"
    kafka_topic: "application_logs"
    kafka_partition: 0
EOF
            print_success "Created basic $CONFIG_FILE"
        fi
    fi

    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        print_info "Creating .env from example..."
        cp ".env.example" ".env"
        print_success "Created .env from example"
    fi
}

# Check Kafka connectivity
check_kafka() {
    local kafka_host=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f1)
    local kafka_port=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f2 | cut -d, -f1)

    if ! nc -z "$kafka_host" "$kafka_port" 2>/dev/null; then
        print_warning "Kafka not accessible on $kafka_host:$kafka_port"
        print_info "Use: ./run.sh kafka start"
        return 1
    else
        print_success "Kafka is accessible on $kafka_host:$kafka_port"
        return 0
    fi
}

# Pre-run checks
pre_run_checks() {
    print_dev "Performing pre-run checks..."

    check_config

    print_info "Checking Kafka connectivity..."
    check_kafka || true

    # Load and export environment variables
    if [ -f ".env" ]; then
        print_info "Loading environment from .env file..."
        export $(grep -v '^#' .env | xargs) 2>/dev/null || true
    fi

    export RUST_LOG HOST PORT KAFKA_BOOTSTRAP_SERVERS

    print_dev "Configuration:"
    print_dev "  Binary: $BINARY_NAME"
    print_dev "  Config File: $CONFIG_FILE"
    print_dev "  Log Level: $RUST_LOG"
    print_dev "  Host: $HOST"
    print_dev "  Port: $PORT"
    print_dev "  Kafka: $KAFKA_BOOTSTRAP_SERVERS"
}

# Detect init system (systemd or OpenRC)
detect_init_system() {
    if command -v systemctl &> /dev/null && [ -d "/etc/systemd/system" ]; then
        echo "systemd"
    elif command -v rc-service &> /dev/null && [ -d "/etc/init.d" ]; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

# Handle interrupt signal
cleanup_on_exit() {
    print_info "Shutting down..."
    exit 0
}

trap cleanup_on_exit INT TERM

# Initialize configuration when sourced
init_config