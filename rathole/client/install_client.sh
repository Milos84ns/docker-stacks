#!/bin/bash
# ==============================================================================
# Rathole Client Installer - A comprehensive installation solution
# ==============================================================================

# ================================
# Global Variables & Colors
# ================================

GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
PURPLE='\033[95m'
CYAN='\033[96m'
RESET='\033[0m'

# ================================
# Configuration - Customize These
# ================================

# Configuration files and directories
CLIENT_CONFIG="/etc/rathole/client.toml"
CONFIG_DIR="/etc/rathole"
DATA_DIR="/var/lib/rathole"
LOG_DIR="/var/log/rathole"
PID_FILE="/var/run/rathole/client.pid"

# Service configuration
SERVICE_NAME="rathole-client"
USER="${USER}"
GROUP="$(id -gn)"

# GitHub API for version checking
GH_API_URL="https://api.github.com/repos/rapiz1/rathole/releases/latest"

# ================================
# Functions
# ================================

# Handle errors with message and exit
handle_error() {
    echo -e "${RED}❌ Critical Error: ${RESET}$1"
    echo "Installation terminated."
    exit 1
}

# Trap errors
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Check if running as root
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        handle_error "Must execute with root privileges or using sudo"
    fi
}

# Detect system architecture
detect_architecture() {
    ARCH=$(uname -m)
    
    case "$ARCH" in
        x86_64 | amd64) 
            ARCH="x86_64" 
            ;;
        aarch64 | arm64) 
            ARCH="aarch64" 
            ;;
        arm*) 
            ARCH="armv7" 
            ;;
        *) 
            handle_error "Unsupported architecture: $ARCH" 
    esac
    
    echo "$ARCH"
}

# Get latest release version from GitHub
get_latest_release() {
    RELEASE=$(curl -s "${GH_API_URL}" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    
    if [ -z "$RELEASE" ]; then
        handle_error "Unable to fetch release information"
    fi
    
    echo "$RELEASE"
}

# Download rathole binary
download_rathole() {
    local arch=$(detect_architecture)
    local rel_version=$(get_latest_release)
    local download_url="https://github.com/rapiz1/rathole/releases/download/${rel_version}/rathole-${arch}-unknown-linux-musl.tar.gz"
    
    # Clean up previous installation artifacts
    rm -f "/tmp/${DOWNLOAD_FILE}" && rm -rf "${BINARY_DIR}" 2>/dev/null
    
    echo -e "📥 Downloading rathole..."
    echo -e "  • Architecture: ${arch}"
    echo -e "  • Version: ${rel_version}"
    
    # Perform download with progress feedback
    wget --progress=bar:force:noscroll \
         -O "/tmp/${DOWNLOAD_FILE}" \
         "${download_url}"
         
    if [ $? -ne 0 ]; then
        handle_error "Binary download failed"
    fi
    
    echo -e "✅ Download successful!"
    echo -e "  • File size: $(stat -c '%s' "/tmp/${DOWNLOAD_FILE}") bytes"
}

# Extract and install the binary
install_binary() {
    echo -e "📦 Extracting files..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "/usr/local/rathole" && cd "/usr/local/rathole"
    
    # Extract the tarball
    tar xzf "/tmp/${DOWNLOAD_FILE}" --strip-components=1
    
    if [ $? -ne 0 ]; then
        handle_error "File extraction failed"
    fi
    
    # Create symbolic link for easy access
    ln -sf "/usr/local/rathole/rathole" "/usr/local/bin/rathole"
    
    echo -e "✅ Installation complete!"
}

# Verify the installation
verify_installation() {
    echo -e "🔍 Verifying installation..."
    
    if command -v rathole >/dev/null 2>&1; then
        echo -e "Rathole is installed at: $(which rathole)"
        echo "Version: $(rathole --version)"
    else
        handle_error "Installation verification failed"
    fi
}

# Create necessary directories
create_directories() {
    echo -e "📁 Setting up file system structure..."
    
    # Create configuration and data directories with proper permissions
    mkdir -p "${CONFIG_DIR}" && chmod 755 "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}" && chmod 700 "${DATA_DIR}"
    mkdir -p "${LOG_DIR}" && chmod 755 "${LOG_DIR}"
    
    # Set ownership for security
    chown -R "${USER}:${GROUP}" "/etc/rathole"
    chown -R "${USER}:${GROUP}" "/var/lib/rathole"
    chown -R "${USER}:${GROUP}" "/var/log/rathole"
}

# Generate default configuration file
generate_configuration() {
    echo -e "📝 Creating initial configuration..."
    
    cat > "${CLIENT_CONFIG}" <<EOF
[client]
remote_addr = "example.com:2333"
default_token = "your-secure-token"
heartbeat_timeout = 60
retry_interval = 2

[client.transport]
type = "noise"

[client.transport.tcp]
proxy = "socks5://127.0.0.1:1080"
nodelay = true
keepalive_secs = 20
keepalive_interval = 8

[client.transport.noise]
pattern = "Noise_NK_25519_ChaChaPoly_BLAKE2s"
remote_public_key = "server_public_key_base64_here"

# Service configurations - customize for your environment
[client.services.ssh]
type = "tcp"
local_addr = "127.0.0.1:22"
nodelay = true

[client.services.minecraft]
type = "tcp"
token = "minecraft_token"
local_addr = "127.0.0.1:25565"
retry_interval = 5
EOF
    
    chmod 644 "${CLIENT_CONFIG}"
    
    echo -e "✅ Configuration file created at ${CLIENT_CONFIG}"
    echo -e "${YELLOW}⚠️ Important: Modify settings with your actual server configuration${RESET}"
}

# Configure systemd service
configure_service() {
    echo -e "⚙️ Setting up systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Rathole Client - Secure Tunneling Solution
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
TimeoutStopSec=20
KillSignal=SIGTERM

Environment="RATHOLE_CONFIG=${CLIENT_CONFIG}"
Environment="RATHOLE_DATA_DIR=${DATA_DIR}"
Environment="RATHOLE_LOG_DIR=${LOG_DIR}"
Environment="TZ=\${TZ}"

ExecStart=/usr/local/bin/rathole -c \${RATHOLE_CONFIG}

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"
    
    echo -e "✅ Service configuration completed"
}

# Manage service state
manage_service() {
    echo -e "🔄 Configuring service runtime..."
    
    # Reload systemd to recognize changes
    systemctl daemon-reload
    
    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e "Starting the service..."
        systemctl start "${SERVICE_NAME}"
        
        if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
            handle_error "Service startup failed"
        fi
        
        echo -e "Enabling permanent startup..."
        systemctl enable "${SERVICE_NAME}"
    else
        echo -e "Service is already running!"
    fi
    
    echo -e "✅ Service configuration complete"
}

# Main installation sequence
install_rathole() {
    echo ""
    echo "========================================"
    echo "RATHOLE CLIENT INSTALLATION"
    echo "========================================"
    echo ""
    
    # Phase 1: Binary download and installation
    echo "➡️ Stage 1: Rathole binary deployment"
    download_rathole
    install_binary
    verify_installation
    
    # Phase 2: Configuration setup
    echo "➡️ Stage 2: Configuration infrastructure"
    create_directories
    generate_configuration
    
    # Phase 3: Service configuration
    echo "➡️ Stage 3: Service configuration"
    configure_service
    manage_service
    
    echo ""
    echo "========================================"
    echo "INSTALLATION FINALIZATION"
    echo "========================================"
    echo ""
    
    echo "Post-installation instructions:"
    echo "• Configuration file: ${CLIENT_CONFIG}"
    echo "• Log location: ${LOG_DIR}"
    echo "• Service management: systemctl {start,stop,restart} rathole-client"
}

# ================================
# Script Execution
# ================================

install_rathole
