#!/bin/bash

# Distribution script - Create distribution package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

# Service Template Creation
create_service_templates() {
    # Create systemd service file template
    cat > "$DIST_DIR/scripts/$BINARY_NAME.service" << EOF
[Unit]
Description=$SERVICE_DESCRIPTION
Documentation=$SERVICE_DOCUMENTATION
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
ExecStart=$INSTALL_BIN_DIR/$BINARY_NAME
WorkingDirectory=$INSTALL_CONFIG_DIR
Environment=RUST_LOG=${RUST_LOG:-info}
EnvironmentFile=-$INSTALL_CONFIG_DIR/.env
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$INSTALL_CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Create OpenRC service file template
    cat > "$DIST_DIR/scripts/$BINARY_NAME.openrc" << 'EOF'
#!/sbin/openrc-run

name="collector"
description="Kafka Collector - HTTP to Kafka Bridge"
user="nobody"
group="nogroup"
command="/usr/local/bin/collector"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
command_user="$user:$group"
directory="/usr/local/etc/collector"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner $command_user --mode 0755 /run
}

start() {
    ebegin "Starting $description"
    if [ -f "/usr/local/etc/collector/.env" ]; then
        . "/usr/local/etc/collector/.env"
        export $(grep -v '^#' "/usr/local/etc/collector/.env" | xargs)
    fi
    start-stop-daemon --start --background --make-pidfile --pidfile "$pidfile" \
        --user "$user" --group "$group" --chdir "$directory" --exec "$command"
    eend $?
}

stop() {
    ebegin "Stopping $description"
    start-stop-daemon --stop --pidfile "$pidfile" --user "$user"
    eend $?
}
EOF
}

create_install_script() {
    cat > "$DIST_DIR/scripts/install.sh" << 'EOF'
#!/bin/bash
set -e

BINARY_NAME="collector"
INSTALL_PREFIX="/usr/local"
INSTALL_BIN_DIR="$INSTALL_PREFIX/bin"
INSTALL_CONFIG_DIR="$INSTALL_PREFIX/etc/$BINARY_NAME"

echo "Installing $BINARY_NAME..."

if [ "$EUID" -ne 0 ]; then
    echo "Installation requires sudo privileges"
    exit 1
fi

mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_CONFIG_DIR"

cp "bin/$BINARY_NAME" "$INSTALL_BIN_DIR/"
chmod +x "$INSTALL_BIN_DIR/$BINARY_NAME"
echo "Binary installed to $INSTALL_BIN_DIR/$BINARY_NAME"

cp config/* "$INSTALL_CONFIG_DIR/"
chmod 644 "$INSTALL_CONFIG_DIR"/*
echo "Configuration files installed to $INSTALL_CONFIG_DIR/"

echo "Installation completed!"
echo "Edit configuration files in $INSTALL_CONFIG_DIR/ before running"
EOF
    chmod +x "$DIST_DIR/scripts/install.sh"
}

create_dist_readme() {
    cat > "$DIST_DIR/README.md" << 'EOF'
# Kafka Collector Distribution Package

This package contains the Kafka Collector binary and all necessary files for deployment.

## Quick Installation

1. Run the installation script:
   ```bash
   sudo ./scripts/install.sh
   ```
2. Edit configuration files in `/usr/local/etc/collector/`
3. Install system service (optional):
   - For systemd: `sudo cp scripts/collector.service /etc/systemd/system/`
   - For OpenRC: `sudo cp scripts/collector.openrc /etc/init.d/collector`

## Manual Installation

1. Copy binary: `sudo cp bin/collector /usr/local/bin/`
2. Create config directory: `sudo mkdir -p /usr/local/etc/collector`
3. Copy configs: `sudo cp config/* /usr/local/etc/collector/`
4. Edit configurations as needed
5. Run: `collector`
EOF
}

print_build "Creating distribution package..."

# Check if binary exists
if [ ! -f "target/release/$BINARY_NAME" ]; then
    print_error "Binary not found. Please run 'build' first."
    exit 1
fi

# Create dist directory structure
print_info "Setting up distribution directory structure..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"/{bin,config,scripts,docs}

# Copy binary
print_info "Copying binary..."
cp "target/release/$BINARY_NAME" "$DIST_DIR/bin/"
chmod +x "$DIST_DIR/bin/$BINARY_NAME"

# Copy configuration files
print_info "Copying configuration files..."
if [ -f ".env.example" ]; then
    cp ".env.example" "$DIST_DIR/config/.env"
fi
if [ -f "$CONFIG_FILE.example" ]; then
    cp "$CONFIG_FILE.example" "$DIST_DIR/config/$CONFIG_FILE"
elif [ -f "conf.example.yaml" ]; then
    cp "conf.example.yaml" "$DIST_DIR/config/$CONFIG_FILE"
fi

# Copy documentation
if [ -f "README.md" ]; then
    cp "README.md" "$DIST_DIR/docs/"
fi

# Create service templates and install script
create_service_templates
create_install_script
create_dist_readme

binary_size=$(ls -lah "$DIST_DIR/bin/$BINARY_NAME" | awk '{print $5}')
print_success "Distribution package created in $DIST_DIR/"
print_info "Package size: $binary_size"
print_info "Package contents:"
ls -la "$DIST_DIR"