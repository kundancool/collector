//! # Kafka Collector
//!
//! A high-performance HTTP-to-Kafka bridge that collects HTTP POST requests and forwards them
//! to Apache Kafka topics based on configurable endpoints.
//!
//! ## Features
//!
//! - **Dynamic Endpoints**: Configure multiple HTTP endpoints via YAML that map to Kafka topics and partitions
//! - **Production Ready**: Includes health checks, environment variable support, comprehensive logging, and error handling
//! - **Daemon Mode**: Run as a background daemon with `-d` flag
//! - **Async Processing**: Built with Tokio and Actix-Web for high concurrency
//! - **KRaft Support**: Compatible with modern Kafka without Zookeeper
//!
//! ## Configuration
//!
//! The application is configured via:
//! - Command line arguments (see [`Args`])
//! - Environment variables (.env file support via dotenv)
//! - YAML configuration file (see [`Config`] and [`EndpointConfig`])
//!
//! ## Example
//!
//! ```bash
//! # Run in development mode
//! collector -c conf.yaml
//!
//! # Run as daemon
//! collector -d -c conf.yaml
//! ```

use actix_web::{web, App, HttpResponse, HttpServer};
use clap::Parser;
use daemonize::Daemonize;
use rdkafka::config::ClientConfig;
use rdkafka::producer::{FutureProducer, FutureRecord, Producer};
use serde::Deserialize;
use std::collections::HashSet;
use std::fs::File;
use std::sync::Arc;
use std::time::Duration;

/// Command line arguments for the Kafka Collector
#[derive(Parser, Debug)]
#[command(name = "collector")]
#[command(about = "Kafka Collector - HTTP to Kafka Bridge")]
#[command(version = env!("CARGO_PKG_VERSION"))]
struct Args {
    /// Run in daemon mode
    #[arg(short, long)]
    daemon: bool,

    /// Configuration file path
    #[arg(short, long, default_value = "conf.yaml")]
    config: String,

    /// PID file for daemon mode
    #[arg(long, default_value = "/tmp/collector.pid")]
    pid_file: String,

    /// Working directory for daemon mode
    #[arg(long, default_value = ".")]
    working_dir: String,

    /// Log file for daemon mode (if not specified, uses system logger)
    #[arg(long)]
    log_file: Option<String>,
}

/// Configuration structure for a single endpoint.
/// Each endpoint maps a URL path to a Kafka topic and partition.
#[derive(Debug, Deserialize, Clone)]
struct EndpointConfig {
    /// The HTTP path for the endpoint (e.g., "/api/v1/events")
    path: String,
    /// The Kafka topic to send messages to
    kafka_topic: String,
    /// The Kafka partition to send messages to
    kafka_partition: i32,
}

/// Top-level configuration structure loaded from conf.yaml
#[derive(Debug, Deserialize)]
struct Config {
    /// List of endpoints to configure
    endpoints: Vec<EndpointConfig>,
}

/// Health check handler that returns a simple OK response
async fn health_check() -> HttpResponse {
    HttpResponse::Ok().body("OK")
}

/// Main entry point for the Kafka Collector application.
///
/// This function:
/// 1. Parses command line arguments
/// 2. Handles daemon mode if requested
/// 3. Initializes logging
/// 4. Loads configuration from YAML file
/// 5. Validates configuration
/// 6. Creates Kafka producer and tests connectivity
/// 7. Sets up HTTP server with dynamic endpoints
/// 8. Starts the server
///
/// # Returns
///
/// Returns `Ok(())` on successful completion, or an error if startup fails.
///
/// # Environment Variables
///
/// - `HOST`: Server bind address (default: 127.0.0.1, or 0.0.0.0 if PUBLIC_ACCESS=true)
/// - `PORT`: Server port (default: 8080)
/// - `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (default: localhost:9093)
/// - `KAFKA_MESSAGE_TIMEOUT_MS`: Message timeout in ms (default: 5000)
/// - `KAFKA_DELIVERY_TIMEOUT_MS`: Delivery timeout in ms (default: 5000)
/// - `KAFKA_REQUEST_TIMEOUT_MS`: Request timeout in ms (default: 5000)
/// - `KAFKA_SOCKET_TIMEOUT_MS`: Socket timeout in ms (default: 5000)
/// - `PUBLIC_ACCESS`: Set to "true" for public access (changes host to 0.0.0.0)
/// - `RUST_LOG`: Log level (handled by env_logger)
///
/// # Errors
///
/// This function will return an error if:
/// - Configuration file cannot be read or parsed
/// - Configuration validation fails (duplicate paths, empty values)
/// - Kafka producer cannot be created
/// - HTTP server cannot bind to the specified address
#[actix_web::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Parse command line arguments
    let args = Args::parse();

    // Load environment variables from .env file if present
    dotenv::dotenv().ok();

    // Load service user and group for daemon mode
    let service_user = std::env::var("SERVICE_USER").unwrap_or_else(|_| "nobody".to_string());
    let service_group = std::env::var("SERVICE_GROUP").unwrap_or_else(|_| "daemon".to_string());

    // Handle daemon mode
    if args.daemon {
        daemonize_process(&args, &service_user, &service_group)?;
    }

    // Initialize logging based on mode
    init_logging(&args);

    // Load host and port from environment
    // Default host is 127.0.0.1, but 0.0.0.0 if PUBLIC_ACCESS=true
    let host = std::env::var("HOST").unwrap_or_else(|_| {
        if std::env::var("PUBLIC_ACCESS").unwrap_or_else(|_| "false".to_string()) == "true" {
            "0.0.0.0".to_string()
        } else {
            "127.0.0.1".to_string()
        }
    });
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let server_addr = format!("{}:{}", host, port);

    // Load Kafka configuration from environment (.env file already loaded above)
    let kafka_servers = std::env::var("KAFKA_BOOTSTRAP_SERVERS").unwrap_or_else(|_| "localhost:9093".to_string());
    let message_timeout = std::env::var("KAFKA_MESSAGE_TIMEOUT_MS").unwrap_or_else(|_| "5000".to_string());
    let delivery_timeout = std::env::var("KAFKA_DELIVERY_TIMEOUT_MS").unwrap_or_else(|_| "5000".to_string());
    let request_timeout = std::env::var("KAFKA_REQUEST_TIMEOUT_MS").unwrap_or_else(|_| "5000".to_string());
    let socket_timeout = std::env::var("KAFKA_SOCKET_TIMEOUT_MS").unwrap_or_else(|_| "5000".to_string());

    log::info!("Loading configuration from {}", args.config);
    let config: Config = match std::fs::File::open(&args.config) {
        Ok(file) => serde_yaml::from_reader(file)?,
        Err(e) => {
            log::error!("Failed to open {}: {:?}", args.config, e);
            return Err(e.into());
        }
    };

    // Validate configuration: ensure paths are unique and not empty
    let mut paths = HashSet::new();
    for endpoint in &config.endpoints {
        if endpoint.path.is_empty() {
            return Err("Endpoint path cannot be empty".into());
        }
        if endpoint.kafka_topic.is_empty() {
            return Err(format!("Kafka topic for path {} cannot be empty", endpoint.path).into());
        }
        if !paths.insert(&endpoint.path) {
            return Err(format!("Duplicate path: {}", endpoint.path).into());
        }
    }

    log::info!("Creating Kafka producer with bootstrap servers: {}", kafka_servers);
    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", &kafka_servers)
        .set("message.timeout.ms", &message_timeout)
        .set("delivery.timeout.ms", &delivery_timeout)
        .set("request.timeout.ms", &request_timeout)
        .set("socket.timeout.ms", &socket_timeout)
        .create()
        .map_err(|e| {
            log::error!("Failed to create Kafka producer: {}", e);
            format!("Kafka producer creation failed: {}", e)
        })?;

    // Test Kafka connection by getting metadata
    log::info!("Testing Kafka connection...");
    match producer.client().fetch_metadata(None, Duration::from_secs(5)) {
        Ok(metadata) => {
            let broker_count = metadata.brokers().len();
            if broker_count == 0 {
                log::warn!("No Kafka brokers found in metadata");
            } else {
                log::info!("Successfully connected to Kafka cluster with {} brokers", broker_count);
                for broker in metadata.brokers() {
                    log::info!("  Broker {}: {}:{}", broker.id(), broker.host(), broker.port());
                }
            }
        }
        Err(e) => {
            log::warn!("Could not fetch Kafka metadata (connection may be unstable): {}", e);
            log::info!("Server will start anyway, but Kafka operations may fail");
        }
    }

    let producer = Arc::new(producer);
    let endpoints = config.endpoints;

    // Create endpoint handlers outside the HttpServer closure to avoid duplication
    let mut endpoint_handlers = Vec::new();
    for endpoint in &endpoints {
        let path = endpoint.path.clone();
        let topic = endpoint.kafka_topic.clone();
        let partition = endpoint.kafka_partition;

        log::info!("Registering endpoint: {} -> topic: {}, partition: {}", path, topic, partition);

        endpoint_handlers.push((path, topic, partition));
    }

    log::info!("Starting HTTP server on {}", server_addr);
    HttpServer::new(move || {
        let producer = Arc::clone(&producer);
        let mut app = App::new()
            .app_data(web::Data::new(producer.clone()))
            // Add health check endpoint
            .route("/health", web::get().to(health_check));

        // Register routes from pre-built handlers
        for (path, topic, partition) in &endpoint_handlers {
            let path = path.clone();
            let topic = topic.clone();
            let partition = *partition;
            let producer_clone = Arc::clone(&producer);

            app = app.route(
                &path,
                web::post().to(move |body: web::Bytes| {
                    let topic = topic.clone();
                    let producer = Arc::clone(&producer_clone);
                    async move {
                        // Create Kafka record from request body
                        let record = FutureRecord::to(&topic)
                            .partition(partition)
                            .payload(body.as_ref())
                            .key(""); // Empty key for now; could be enhanced

                        // Send message to Kafka
                        match producer.send(record, Duration::from_secs(0)).await {
                            Ok(delivery) => {
                                log::info!("Message sent to topic {} partition {}: {:?}", topic, partition, delivery);
                                HttpResponse::Ok().json(serde_json::json!({
                                    "status": "success",
                                    "message": "Message sent to Kafka",
                                    "topic": topic,
                                    "partition": partition
                                }))
                            }
                            Err((e, _)) => {
                                log::error!("Failed to send message to Kafka topic {} partition {}: {:?}", topic, partition, e);
                                HttpResponse::InternalServerError().json(serde_json::json!({
                                    "status": "error",
                                    "message": "Failed to send message to Kafka",
                                    "error": e.to_string()
                                }))
                            }
                        }
                    }
                }),
            );
        }

        app
    })
        .bind(&server_addr)?
        .run()
        .await?;

    Ok(())
}

/// Initialize logging based on daemon mode and configuration.
///
/// In normal mode, logs are written to stdout/stderr using env_logger.
/// In daemon mode, logs can be written to a file or to the system logger.
///
/// # Arguments
///
/// * `args` - Command line arguments containing daemon mode settings and log file path
///
/// # Panics
///
/// Panics if the log file cannot be created when running in daemon mode with a log file specified.
fn init_logging(args: &Args) {
    if args.daemon {
        // In daemon mode, use a custom logger
        if let Some(log_file) = &args.log_file {
            // Log to file
            let log_file = File::create(log_file).expect("Could not create log file");
            env_logger::Builder::from_default_env()
                .target(env_logger::Target::Pipe(Box::new(log_file)))
                .init();
        } else {
            // Log to syslog or journal (simplified version)
            env_logger::Builder::from_default_env()
                .format_timestamp_secs()
                .init();
        }
    } else {
        // Normal mode - log to stdout/stderr
        env_logger::init();
    }
}

/// Daemonize the current process using the daemonize crate.
///
/// This function forks the process into the background, sets up a PID file,
/// changes the working directory, and switches to a non-privileged user.
///
/// # Arguments
///
/// * `args` - Command line arguments containing daemon configuration
/// * `service_user` - User to run the daemon as
/// * `service_group` - Group to run the daemon as
///
/// # Returns
///
/// Returns `Ok(())` if daemonization succeeds, or an error if it fails.
///
/// # Security
///
/// The daemon process runs as the specified user and group for security.
/// The umask is set to 0o022 to ensure appropriate file permissions.
///
/// # Errors
///
/// This function will return an error if:
/// - The PID file cannot be created
/// - The process cannot be forked
/// - User/group switching fails
/// - Working directory cannot be changed
fn daemonize_process(args: &Args, service_user: &str, service_group: &str) -> Result<(), Box<dyn std::error::Error>> {
    let daemon = Daemonize::new()
        .pid_file(&args.pid_file)
        .chown_pid_file(true)
        .working_directory(&args.working_dir)
        .user(service_user)
        .group(service_group)
        .umask(0o022);

    match daemon.start() {
        Ok(_) => {
            println!("Successfully daemonized. Check {} for PID.", args.pid_file);
            Ok(())
        }
        Err(e) => {
            eprintln!("Error daemonizing: {}", e);
            Err(e.into())
        }
    }
}