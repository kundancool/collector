#!/bin/bash

# OS Package build script for .deb and .apk packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

print_build "Building OS packages..."

VERSION="0.1.10"
ARCH="amd64"
PACKAGE_NAME="collector"
BUILD_DIR="$SCRIPT_DIR/../../build"
PACKAGE_DIR="$BUILD_DIR/package"

# Clean
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Download binaries
curl -L -o "$PACKAGE_DIR/collector-gnu" "https://github.com/kundancool/collector/releases/download/v${VERSION}/collector-x86_64-linux-gnu"
curl -L -o "$PACKAGE_DIR/collector-musl" "https://github.com/kundancool/collector/releases/download/v${VERSION}/collector-x86_64-linux-musl"
chmod +x "$PACKAGE_DIR/collector-gnu" "$PACKAGE_DIR/collector-musl"

# Build .deb package
build_deb() {
    print_info "Building .deb package..."

    DEB_DIR="$PACKAGE_DIR/deb"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/usr/bin"
    mkdir -p "$DEB_DIR/etc/collector"
    mkdir -p "$DEB_DIR/etc/systemd/system"

    # Binary (use gnu for Ubuntu)
    cp "$PACKAGE_DIR/collector-gnu" "$DEB_DIR/usr/bin/collector"

    # Config files
    cp "$SCRIPT_DIR/../../conf.example.yaml" "$DEB_DIR/etc/collector/config.yaml"
    cp "$SCRIPT_DIR/../../.env.example" "$DEB_DIR/etc/collector/.env"

    # Service file
    cat > "$DEB_DIR/etc/systemd/system/collector.service" << 'EOF'
[Unit]
Description=Kafka Collector - HTTP to Kafka Bridge
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
EnvironmentFile=/etc/collector/.env
ExecStart=/usr/bin/collector -c /etc/collector/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: Your Name <your.email@example.com>
Description: Kafka Collector - HTTP to Kafka Bridge
Depends: systemd
EOF

    # Postinst script
    cat > "$DEB_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
systemctl daemon-reload
systemctl enable collector
EOF
    chmod +x "$DEB_DIR/DEBIAN/postinst"

    # Build deb
    dpkg-deb --build "$DEB_DIR" "$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    print_success ".deb package built: $BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
}

# Build .apk package structure
build_apk() {
    print_info "Building .apk package structure..."

    APK_DIR="$PACKAGE_DIR/apk"
    mkdir -p "$APK_DIR"

    # APKBUILD file
    cat > "$APK_DIR/APKBUILD" << EOF
pkgname=$PACKAGE_NAME
pkgver=$VERSION
pkgrel=1
pkgdesc="Kafka Collector - HTTP to Kafka Bridge"
url="https://github.com/kundancool/collector"
arch="x86_64"
license="MIT"
depends="openrc"
source="collector-x86_64-linux-musl::https://github.com/kundancool/collector/releases/download/v\$pkgver/collector-x86_64-linux-musl"

package() {
    install -Dm755 "\$srcdir/collector-x86_64-linux-musl" "\$pkgdir/usr/bin/collector"
    install -Dm644 "\$srcdir/../conf.example.yaml" "\$pkgdir/etc/collector/config.yaml"
    install -Dm644 "\$srcdir/../.env.example" "\$pkgdir/etc/collector/.env"
    install -Dm755 "\$srcdir/../collector.initd" "\$pkgdir/etc/init.d/collector"
    install -Dm644 "\$srcdir/../collector.confd" "\$pkgdir/etc/conf.d/collector"
}
EOF

    # Init script
    cat > "$APK_DIR/collector.initd" << 'EOF'
#!/sbin/openrc-run

description="Kafka Collector - HTTP to Kafka Bridge"
command="/usr/bin/collector"
command_args="-c /etc/collector/config.yaml"
command_user="nobody:nogroup"
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
    need net
}
EOF
    chmod +x "$APK_DIR/collector.initd"

    # Conf file
    cat > "$APK_DIR/collector.confd" << 'EOF'
# Config file for collector
EOF

    print_info ".apk package structure created in $APK_DIR"
    print_info "To build .apk, run: cd $APK_DIR && abuild -r"
}

build_deb
build_apk

print_success "OS package build complete!"