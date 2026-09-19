#!/bin/bash
# ==============================================================================
# Rathole v0.5.0 Installation Script - ARM64 (aarch64)
# ==============================================================================

# ================================
# Global Variables & Colors
# ================================

GREEN='\033[92m'
BLUE='\033[94m'
YELLOW='\033[93m'
RED='\033[91m'
RESET='\033[0m'

BINARY_URL="https://github.com/rathole-org/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-musl.zip"
BINARY_NAME="rathole"
INSTALL_PATH="/usr/local/bin/${BINARY_NAME}"
CONFIG_FILE="/etc/rathole/config.toml"

# ================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root."
    exit 1
fi

# ================================
# Installation Functions
# ================================

# Function to handle errors
handle_error() {
    echo -e "${RED}⚠️  ERROR: $1${RESET}"
    exit 1
}

trap 'handle_error "Error at line $LINENO"' ERR

# Create necessary directories
mkdir -p /etc/rathole /var/lib/rathole /var/log/rathole

# Download Rathole binary
echo -e "${BLUE}Downloading Rathole v0.5.0...${RESET}"
wget --output-document=rathole.zip "${BINARY_URL}"

if [ $? -ne 0 ]; then
    handle_error "Failed to download Rathole binary"
fi

# Extract the files
unzip rathole.zip

if [ $? -ne 0 ]; then
    handle_error "Failed to extract Rathole files"
fi

# Move binary to /usr/local/bin
mv "${BINARY_NAME}" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"

echo -e "${GREEN}✓ Rathole binary installed to ${INSTALL_PATH}${RESET}"

# ================================
# Configuration Setup
# ================================

echo -e "${BLUE}Creating configuration file...${RESET}"
cat > "${CONFIG_FILE}" <<EOL
# ==============================================================================
# Rathole v0.5.0 Configuration File
# ==============================================================================

# Client configuration
[client]
remote_addr = "your-rathole-server:2333"
default_token = "your-secure-token-here"

# Transport settings
[client.transport]
type = "noise"

[client.transport.tcp]
proxy = "socks5://127.0.0.1:1080"
nodelay = true
keepalive_secs = 60
keepalive_interval = 30

[client.transport.noise]
pattern = "Noise_NK_25519_ChaChaPoly_BLAKE2s"
remote_public_key = "server-public-key-base64-here"

# Services configuration
[client.services.ssh]
type = "tcp"
local_addr = "127.0.0.1:22"
nodelay = true

[client.services.http-bridge]
type = "http"
local_addr = "127.0.0.1:8000"
target = "http://your-backend-service:3000"

EOL

echo -e "${GREEN}✓ Configuration file created at ${CONFIG_FILE}${RESET}"
echo -e "${YELLOW}❗ Important: Edit the configuration with your actual server details${RESET}"

# ================================
# Service Configuration
# ================================

echo -e "${BLUE}Setting up systemd service...${RESET}"
cat > "/etc/systemd/system/rathole.service" <<EOL
[Unit]
Description=Rathole Tunneling Service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
WorkingDirectory=/etc/rathole
ExecStart=${INSTALL_PATH} --config ${CONFIG_FILE}

StandardOutput=append:/var/log/rathole/rathole.log
StandardError=append:/var/log/rathole/rathole-errors.log

[Install]
WantedBy=multi-user.target
EOL

chmod 644 "/etc/systemd/system/rathole.service"

systemctl daemon-reload

# Start the service
echo -e "${BLUE}Starting Rathole service...${RESET}"
systemctl enable rathole --now

sleep 2

echo ""
echo "========================================"
echo "RATHOLE v0.5.0 INSTALLATION COMPLETE"
echo "========================================"
echo ""
echo "Access your logs:    journalctl -u rathole"
echo "Configuration file:  ${CONFIG_FILE}"
echo "Service status:"
systemctl status rathole
