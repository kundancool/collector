# Kafka Collector

A high-performance Rust HTTP-to-Kafka bridge that collects HTTP POST requests and forwards them to Apache Kafka topics based on configurable endpoints.

## Features

- **Dynamic Endpoints**: Configure multiple HTTP endpoints via YAML that map to Kafka topics and partitions
- **Production Ready**: Includes health checks, environment variable support, comprehensive logging, and error handling
- **Daemon Mode**: Run as a background daemon with `-d` flag
- **Modular Scripts**: Comprehensive development, build, and deployment tooling
- **Service Management**: Automatic systemd/OpenRC service creation
- **KRaft Support**: Compatible with modern Kafka without Zookeeper
- **Containerized**: Docker support with KRaft-mode Kafka
- **Async Processing**: Built with Tokio and Actix-Web for high concurrency

## Prerequisites

- Rust 1.70 or later
- Apache Kafka cluster (KRaft mode supported)
- Docker (for containerized deployment)
- netcat (for connectivity checks)

## Quick Start

### Local Development

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd kafka-rust
   cp .env.example .env
   ```

2. **Start Kafka (using included Docker setup):**
   ```bash
   ./kafka.sh start
   ```

3. **Run in development mode:**
   ```bash
   ./run.sh dev
   # or simply
   ./run.sh
   ```

4. **Run with hot reload:**
   ```bash
   ./run.sh watch
   ```

5. **Test the application:**
   ```bash
   ./run.sh e2e
   ```

### Docker Deployment

1. **Build the image:**
   ```bash
   docker build -t collector .
   ```

2. **Run the container:**
   ```bash
   docker run -p 8080:8080 \
     -e KAFKA_BOOTSTRAP_SERVERS=your-kafka-host:9092 \
     -v $(pwd)/conf.yaml:/app/conf.yaml \
     collector
   ```

## Script Commands

The project includes a comprehensive set of modular scripts accessible via the main `run.sh` dispatcher:

### Development Commands
- `./run.sh dev` - Build and run in development mode (default)
- `./run.sh release` - Build and run in release mode
- `./run.sh watch` - Run with file watching for hot reload
- `./run.sh check` - Run code checks (fmt, clippy, test)
- `./run.sh test` - Run unit tests
- `./run.sh e2e` - Run end-to-end tests with Kafka verification

### Build & Package Commands
- `./run.sh build` - Build release binary
- `./run.sh clean` - Clean all build artifacts
- `./run.sh dist` - Create distribution package
- `./run.sh package` - Build and create distribution package

### Deployment Commands
- `./run.sh install` - Install binary and configs system-wide (requires sudo)
- `./run.sh service` - Create and install system service (requires sudo)
- `./run.sh deploy` - Complete deployment pipeline

### Utility Commands
- `./run.sh kafka start|stop|status|test` - Manage Kafka
- `./run.sh status` - Show project and system status
- `./run.sh health` - Check application health
- `./run.sh help` - Show help message

## Configuration

### Environment Variables (.env)

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (default: localhost:9093)
- `HOST`: HTTP server bind host (default: 127.0.0.1)
- `PORT`: HTTP server bind port (default: 8080)
- `RUST_LOG`: Log level (default: info)
- `BINARY_NAME`: Binary name (default: collector)
- `CONFIG_FILE`: Configuration file path (default: conf.yaml)

### Build & Deployment Configuration
- `INSTALL_PREFIX`: Installation prefix (default: /usr/local)
- `INSTALL_BIN_DIR`: Binary installation directory
- `INSTALL_CONFIG_DIR`: Configuration installation directory
- `SERVICE_USER`: Service user (default: nobody)
- `SERVICE_GROUP`: Service group (default: nogroup)

### Endpoints Configuration (conf.yaml)

Define your endpoints in `conf.yaml`:

```yaml
endpoints:
  - path: "/api/v1/events"
    kafka_topic: "user_events"
    kafka_partition: 0
  - path: "/api/v1/actions"
    kafka_topic: "user_actions"
    kafka_partition: 1
```

## API Endpoints

- `POST /<configured-path>`: Forward request body to configured Kafka topic/partition
- `GET /health`: Health check endpoint

## Command Line Arguments

The collector binary supports the following arguments:

```bash
collector [OPTIONS]

Options:
  -c, --config <FILE>    Set configuration file path [default: conf.yaml]
  -d, --daemon          Run as daemon in background
  -h, --help            Print help information
  -V, --version         Print version information
```

Examples:
```bash
# Run with custom config
collector -c /path/to/config.yaml

# Run as daemon
collector -d

# Run as daemon with custom config
collector -d -c /path/to/config.yaml
```

## Testing

Run comprehensive tests to verify functionality:

```bash
# Unit tests
./run.sh test

# End-to-end tests with Kafka
./run.sh e2e

# Code quality checks
./run.sh check
```

The end-to-end tests will:
- Start the server
- Send test POST requests to all configured endpoints
- Verify responses
- Check health endpoint

## Production Deployment

### System Installation

Install the binary and create a system service:

```bash
# Build and install
./run.sh build
sudo ./run.sh install

# Create and enable system service
sudo ./run.sh service
sudo systemctl enable collector
sudo systemctl start collector

# Check status
./run.sh status
```

### Distribution Package

Create a distribution package for deployment:

```bash
./run.sh package
```

This creates a `dist/` directory with:
- Binary in `bin/`
- Configuration templates in `config/`
- Installation scripts in `scripts/`
- Service files for systemd/OpenRC

### Using Docker Compose (KRaft Mode)

The project includes a modern KRaft-mode Kafka setup. Use the included `docker-compose.yml`:

```bash
# Start Kafka and other services
./kafka.sh start

# Build and run collector
./run.sh build
./run.sh release
```

Or run everything with Docker:

```bash
docker-compose up -d
```

### Kubernetes

Use the provided Dockerfile to create a Kubernetes deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: collector
spec:
  replicas: 3
  selector:
    matchLabels:
      app: collector
  template:
    metadata:
      labels:
        app: collector
    spec:
      containers:
      - name: collector
        image: your-registry/collector:latest
        ports:
        - containerPort: 8080
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "kafka-service:9092"
        volumeMounts:
        - name: config
          mountPath: /app/conf.yaml
          subPath: conf.yaml
      volumes:
      - name: config
        configMap:
          name: collector-config
```

## Monitoring

- Logs are output to stdout/stderr
- Health check available at `/health`
- Consider integrating with monitoring tools like Prometheus for metrics

## Development

### Development Workflow

```bash
# Setup development environment
cp .env.example .env
./kafka.sh start

# Development mode with hot reload
./run.sh watch

# Run all code quality checks
./run.sh check

# Run tests
./run.sh test

# End-to-end testing
./run.sh e2e
```

### Manual Commands

For direct cargo usage:
- Run tests: `cargo test`
- Format code: `cargo fmt`
- Lint: `cargo clippy`
- Build docs: `cargo doc --open`

### Project Structure

```
kafka-rust/
├── src/
│   └── main.rs              # Main application code
├── scripts/
│   ├── common.sh           # Shared utilities
│   ├── dev/                # Development scripts
│   ├── build/              # Build and packaging scripts
│   ├── deploy/             # Deployment scripts
│   └── utils/              # Utility scripts
├── run.sh                  # Main script dispatcher
├── kafka.sh               # Kafka management script
├── docker-compose.yml     # KRaft-mode Kafka setup
├── .env.example           # Environment configuration template
└── conf.example.yaml      # Endpoint configuration template
```

## License

[Add your license here]