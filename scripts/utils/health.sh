#!/bin/bash

# Health script - Check application health

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

check_kafka() {
    local kafka_host=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f1)
    local kafka_port=$(echo $KAFKA_BOOTSTRAP_SERVERS | cut -d: -f2 | cut -d, -f1)

    if ! nc -z "$kafka_host" "$kafka_port" 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

print_info "Checking application health..."

if ! check_kafka; then
    print_warning "Kafka is not accessible"
fi

# Try to connect to the application
if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
    local response=$(curl -s "http://$HOST:$PORT/health")
    print_success "✓ Application: Running (Health: $response)"
else
    print_warning "⚠ Application: Not running or not accessible"
    print_info "Start with development mode"
fi