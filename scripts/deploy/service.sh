#!/bin/bash

# Service script - Create and install system service

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

create_systemd_service() {
    local service_file="/etc/systemd/system/$BINARY_NAME.service"

    cat > "$service_file" << EOF
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

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$INSTALL_CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    systemctl daemon-reload
    print_success "Systemd service created: $service_file"
    print_info "Enable with: sudo systemctl enable $BINARY_NAME"
    print_info "Start with: sudo systemctl start $BINARY_NAME"
}

create_openrc_service() {
    local service_file="/etc/init.d/$BINARY_NAME"

    cat > "$service_file" << EOF
#!/sbin/openrc-run

name="$BINARY_NAME"
description="$SERVICE_DESCRIPTION"
user="$SERVICE_USER"
group="$SERVICE_GROUP"
command="$INSTALL_BIN_DIR/$BINARY_NAME"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"
command_user="\$user:\$group"
directory="$INSTALL_CONFIG_DIR"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner \$command_user --mode 0755 /run
}

start() {
    ebegin "Starting \$description"
    if [ -f "$INSTALL_CONFIG_DIR/.env" ]; then
        . "$INSTALL_CONFIG_DIR/.env"
        export \$(grep -v '^#' "$INSTALL_CONFIG_DIR/.env" | xargs)
    fi
    start-stop-daemon --start --background --make-pidfile --pidfile "\$pidfile" \\
        --user "\$user" --group "\$group" --chdir "\$directory" --exec "\$command"
    eend \$?
}

stop() {
    ebegin "Stopping \$description"
    start-stop-daemon --stop --pidfile "\$pidfile" --user "\$user"
    eend \$?
}
EOF

    chmod +x "$service_file"
    print_success "OpenRC service created: $service_file"
    print_info "Enable with: sudo rc-update add $BINARY_NAME default"
    print_info "Start with: sudo rc-service $BINARY_NAME start"
}

print_build "Setting up system service for $BINARY_NAME..."

# Check if binary is installed
if [ ! -f "$INSTALL_BIN_DIR/$BINARY_NAME" ]; then
    print_error "Binary not found at $INSTALL_BIN_DIR/$BINARY_NAME"
    print_error "Please run install script first."
    exit 1
fi

# Check for sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Service creation requires sudo privileges"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect init system
local init_system=$(detect_init_system)
print_info "Detected init system: $init_system"

case "$init_system" in
    "systemd")
        create_systemd_service
        ;;
    "openrc")
        create_openrc_service
        ;;
    *)
        print_error "Could not detect init system (systemd or OpenRC)"
        exit 1
        ;;
esac

print_success "Service setup completed!"