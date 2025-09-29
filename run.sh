#!/bin/bash

# Main Dispatcher Script for Kafka Collector
# Calls individual scripts based on command

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show usage information
show_usage() {
    echo "Modular Development & Deployment Script for Kafka Collector"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Development Commands:"
    echo "  dev         Build and run in development mode (default)"
    echo "  release     Build and run in release mode"
    echo "  watch       Run with file watching (requires cargo-watch)"
    echo "  check       Run code checks (fmt, clippy, test)"
    echo "  test        Run unit tests"
    echo "  e2e         Run end-to-end tests with Kafka verification"
    echo ""
    echo "Build & Package Commands:"
    echo "  build       Build release binary"
    echo "  clean       Clean all build artifacts"
    echo "  dist        Create distribution package"
    echo "  package     Build and create distribution package"
    echo ""
    echo "Deployment Commands:"
    echo "  install     Install binary and configs system-wide (requires sudo)"
    echo "  service     Create and install system service (requires sudo)"
    echo "  deploy      Complete deployment: build + package + install + service"
    echo ""
    echo "Utility Commands:"
    echo "  kafka       Manage Kafka (start/stop/status/test)"
    echo "  status      Show project and system status"
    echo "  health      Check application health"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  RUST_LOG              Set log level (default: info)"
    echo "  HOST                  Server host (default: 127.0.0.1)"
    echo "  PORT                  Server port (default: 8080)"
    echo "  KAFKA_BOOTSTRAP_SERVERS  Kafka servers (default: localhost:9093)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run in development mode"
    echo "  $0 dev                # Same as above"
    echo "  $0 release            # Build and run in release mode"
    echo "  $0 watch              # Run with hot reload"
    echo "  $0 check              # Run all code checks"
    echo "  $0 e2e                # Run end-to-end tests"
    echo "  $0 build              # Build release binary"
    echo "  $0 package            # Create distribution package"
    echo "  $0 deploy             # Complete deployment pipeline"
    echo "  $0 kafka start        # Start Kafka"
    echo "  $0 status             # Show status of everything"
    echo "  RUST_LOG=debug $0     # Run with debug logging"
}

# Main script logic
case "${1:-dev}" in
    # Development Commands
    "dev")
        exec "$SCRIPT_DIR/scripts/dev/dev.sh"
        ;;
    "release")
        exec "$SCRIPT_DIR/scripts/dev/release.sh"
        ;;
    "watch")
        exec "$SCRIPT_DIR/scripts/dev/watch.sh"
        ;;
    "check")
        exec "$SCRIPT_DIR/scripts/dev/check.sh"
        ;;
    "test")
        exec "$SCRIPT_DIR/scripts/dev/test.sh"
        ;;
    "e2e")
        exec "$SCRIPT_DIR/scripts/utils/e2e.sh"
        ;;

    # Build & Package Commands
    "build")
        exec "$SCRIPT_DIR/scripts/build/build.sh"
        ;;
    "clean")
        exec "$SCRIPT_DIR/scripts/build/clean.sh"
        ;;
    "dist")
        exec "$SCRIPT_DIR/scripts/build/dist.sh"
        ;;
    "package")
        exec "$SCRIPT_DIR/scripts/build/package.sh"
        ;;

    # Deployment Commands
    "install")
        exec "$SCRIPT_DIR/scripts/deploy/install.sh"
        ;;
    "service")
        exec "$SCRIPT_DIR/scripts/deploy/service.sh"
        ;;
    "deploy")
        exec "$SCRIPT_DIR/scripts/deploy/deploy.sh"
        ;;

    # Utility Commands
    "kafka")
        if [ -f "./kafka.sh" ]; then
            exec ./kafka.sh "${@:2}"
        else
            echo "Error: kafka.sh not found"
            exit 1
        fi
        ;;
    "status")
        exec "$SCRIPT_DIR/scripts/utils/status.sh"
        ;;
    "health")
        exec "$SCRIPT_DIR/scripts/utils/health.sh"
        ;;
    "help")
        show_usage
        ;;

    # Unknown command
    *)
        echo "Error: Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac