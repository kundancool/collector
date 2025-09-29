#!/bin/bash

# End-to-end test script - Run comprehensive tests with Kafka

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

pre_run_checks() {
    print_dev "Performing pre-run checks..."

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

print_dev "Running end-to-end tests..."
check_rust
pre_run_checks

if ! check_kafka; then
    print_error "Kafka is required for end-to-end tests"
    print_info "Start Kafka with: ./kafka.sh start"
    exit 1
fi

print_info "Building application..."
cargo build

print_info "Starting server for testing..."
cargo run &
local SERVER_PID=$!

# Wait for server to start
sleep 3

print_info "Running endpoint tests..."

# Test /api/v1/events
print_info "Testing /api/v1/events"
local data1='{"event": "click", "user_id": 123, "timestamp": "'$(date -Iseconds)'"}'
local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$data1" http://$HOST:$PORT/api/v1/events)
print_info "Response: $response"

if echo "$response" | grep -q "success"; then
    print_success "✓ /api/v1/events working"
else
    print_error "✗ /api/v1/events failed"
fi

# Test /api/v1/actions
print_info "Testing /api/v1/actions"
local data2='{"action": "login", "user_id": 456, "timestamp": "'$(date -Iseconds)'"}'
local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$data2" http://$HOST:$PORT/api/v1/actions)
print_info "Response: $response"

if echo "$response" | grep -q "success"; then
    print_success "✓ /api/v1/actions working"
else
    print_error "✗ /api/v1/actions failed"
fi

# Test /api/v1/logs
print_info "Testing /api/v1/logs"
local data3='{"level": "error", "message": "Test log message", "timestamp": "'$(date -Iseconds)'"}'
local response=$(curl -s -X POST -H "Content-Type: application/json" -d "$data3" http://$HOST:$PORT/api/v1/logs)
print_info "Response: $response"

if echo "$response" | grep -q "success"; then
    print_success "✓ /api/v1/logs working"
else
    print_error "✗ /api/v1/logs failed"
fi

# Test health check
print_info "Testing health check"
local health_response=$(curl -s http://$HOST:$PORT/health)
print_info "Health response: $health_response"

if [ "$health_response" = "OK" ]; then
    print_success "✓ Health check working"
else
    print_error "✗ Health check failed"
fi

# Clean up: stop the server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

print_success "End-to-end tests completed"