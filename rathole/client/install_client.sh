#!/bin/bash
# ==============================================================================
# Rathole v0.5.0 Installation Script with Advanced Logging
# ==============================================================================

# ================================
# Global Variables & Colors
# ================================

GREEN='\033[92m'
BLUE='\033[94m'
CYAN='\033[96m'
YELLOW='\033[93m'
RED='\033[91m'
RESET='\033[0m'

BINARY_URL="https://github.com/rathole-org/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
BINARY_NAME="rathole"
INSTALL_PATH="/usr/local/bin/${BINARY_NAME}"
CONFIG_FILE="/etc/rathole/config.toml"

# Logging configuration
LOG_DIR="/opt/rathole/logs"
STDOUT_LOG="${LOG_DIR}/rathole.stdout.log"
STDERR_LOG="${LOG_DIR}/rathole.stderr.log"
ACCESS_LOG="${LOG_DIR}/access.log"
ERROR_LOG="${LOG_DIR}/error.log"

# ================================
# Package Manager Detection
# ================================

detect_package_manager() {
    if type -P dnf &> /dev/null; then
        return 0
    elif type -P yum &> /dev/null; then
        return 0
    elif type -P apt-get &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    echo -e "${BLUE}Checking for required tools...${RESET}"
    
    # Check and install wget if missing
    if ! command -v wget &> /dev/null; then
        echo -e "${YELLOW}Installing wget...${RESET}"
        
        if detect_package_manager; then
            if [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
                yum -y install wget unzip || dnf -y install wget unzip
            elif [ -f /etc/os-release ]; then
                apt-get update && apt-get -y install wget unzip
            fi
        else
            echo -e "${RED}No package manager found! Manual installation required.${RESET}"
            exit 1
        fi
    fi
    
    # Verify dependencies are installed
    if ! command -v wget &> /dev/null || ! command -v unzip &> /dev/null; then
        echo -e "${RED}Dependency installation failed. Exiting...${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Dependencies are installed${RESET}"
}

# ================================
# Logging Setup
# ================================

setup_logging() {
    echo -e "\n${BLUE}Configuring logging...${RESET}"
    
    # Create logging directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    # Set proper permissions
    chown -R root:root "${LOG_DIR}"
    chmod 755 "${LOG_DIR}"
    
    # Create log files if they don't exist
    touch "${STDOUT_LOG}" && touch "${STDERR_LOG}" && touch "${ACCESS_LOG}" && touch "${ERROR_LOG}"
    
    # Set permissions for log files
    chown root:root "${LOG_DIR}/*.log"
    chmod 644 "${LOG_DIR}/*.log"
    
    echo -e "${GREEN}✓ Logging directory and files created at ${LOG_DIR}${RESET}"
}

# ================================
# Service Configuration with Enhanced Logging
# ================================

configure_service() {
    echo -e "\n${BLUE}Creating systemd service configuration...${RESET}"
    
# Ensure your service file matches this:
cat > /etc/systemd/system/rathole.service <<EOL
[Unit]
Description=Rathole Tunneling Service
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
WorkingDirectory=/etc/rathole

# Use absolute path to binary
ExecStart=${INSTALL_PATH} --config ${CONFIG_FILE}

StandardOutput=append:/var/log/rathole/client.log
StandardError=append:/var/log/rathole/client-errors.log

[Install]
WantedBy=multi-user.target
EOL
    
    chmod 644 "/etc/systemd/system/rathole.service"
    
    echo -e "${GREEN}✓ Service file with advanced logging configured${RESET}"
}

# ================================
# Main Installation Functions
# ================================

download_rathole() {
    echo -e "\n${BLUE}Downloading Rathole v0.5.0...${RESET}"
    
    # Create temporary directory if not exists
    mkdir -p /tmp/rathole-download
    
    # Download the binary
    wget --output-file=/tmp/rathole-download/download.log --progress=bar "${BINARY_URL}" -P /tmp/rathole-download/
    
    # Check download result
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed. Checking internet connectivity...${RESET}"
        
        # Test internet connection
        if ping -c 1 github.com &> /dev/null; then
            echo -e "${YELLOW}Internet connection active. Retrying download...${RESET}"
            wget --output-file=/tmp/rathole-download/download.log --progress=bar "${BINARY_URL}" -P /tmp/rathole-download/
        else
            handle_error "No internet access detected"
        fi
    fi
    
    echo -e "${GREEN}✓ Download complete! File saved to /tmp/rathole-download${RESET}"
}

install_rathole() {
    echo -e "\n${BLUE}Installing Rathole...${RESET}"
    
    # Check if binary already exists
    if [ -f "${INSTALL_PATH}" ]; then
        echo -e "Rathole is already installed at ${INSTALL_PATH}"
        return 0
    fi
    
    # Extract the downloaded file
    echo -e "Extracting..."
    unzip /tmp/rathole-download/*.zip -d /tmp/rathole-installation/
    
    if [ $? -ne 0 ]; then
        handle_error "Failed to extract Rathole files"
    fi
    
    # Move binary to installation path
    mv /tmp/rathole-installation/${BINARY_NAME} ${INSTALL_PATH}
    
    # Set executable permissions
    chmod +x ${INSTALL_PATH}
    
    echo -e "${GREEN}✓ Rathole installed successfully at ${INSTALL_PATH}${RESET}"
}

configure_rathole() {
    echo -e "\n${BLUE}Configuring Rathole...${RESET}"
    
    # Create configuration directory if it doesn't exist
    mkdir -p $(dirname ${CONFIG_FILE})
    
    # Check if config file already exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        cat > "${CONFIG_FILE}" <<EOL
# ==============================================================================
# Rathole v0.5.systemd Configuration File with Logging Integration
# ==============================================================================

[client]
remote_addr = "your-rathole-server:2333"
default_token = "secure-token-here"

[client.transport.tcp]
proxy = "socks5://127.0.0.1:1080"
nodelay = true
keepalive_secs = 60

# Logging configuration within Rathole
[logging]
level = "info"
format = "text"
output = "/var/log/rathole/rathole.log"

# Services configuration
[client.services.ssh]
type = "tcp"
local_addr = "127.0.0.1:22"
EOL
        
        echo -e "${GREEN}✓ Created new configuration file${RESET}"
    else
        echo -e "Configuration file already exists at ${CONFIG_FILE}"
    fi
    
    echo -e "${YELLOW}❗ Please edit ${CONFIG_FILE} with your actual server details${RESET}"
}

manage_service() {
    echo -e "\n${BLUE}Managing Rathole service...${RESET}"
    
    # Reload systemd to apply changes
    systemctl daemon-reload
    
    # Check current service status
    echo -e "Current status:"
    systemctl status rathole
    
    echo -e "\nEnabling and starting service..."
    systemctl enable rathole --now
    
    echo -e "\nStatus after start:"
    systemctl status rathole
}

verify_installation() {
    echo -e "\n${BLUE}Verifying installation...${RESET}"
    
    # Check binary
    if [ -x "${INSTALL_PATH}" ]; then
        echo "  ✓ Found Rathole binary at ${INSTALL_PATH}"
        echo "     Version: $(${INSTALL_PATH} --version)"
    else
        echo "  ✗ Rathole binary not found"
        return 1
    fi
    
    # Check configuration
    if [ -f "${CONFIG_FILE}" ]; then
        echo "  ✓ Configuration file exists at ${CONFIG_FILE}"
    else
        echo "  ✗ Configuration file missing"
        return 1
    fi
    
    # Check service
    if systemctl is-active --quiet rathole; then
        echo "  ✓ Rathole service is running"
    else
        echo "  ✗ Rathole service not active"
        return 1
    fi
    
    return 0
}

# ================================
# Error Handling
# ================================

handle_error() {
    echo -e "${RED}❌ Critical Error: ${RESET}$1"
    echo "Terminating installation..."
    exit 1
}

trap 'handle_error "Error occurred at line $LINENO"' ERR

# ================================
# Main Execution
# ================================

echo -e "${BLUE}Rathole v0.5.systemd Installation Script with Advanced Logging${RESET}"
echo "========================================"

install_dependencies
setup_logging
download_rathole
install_rathole
configure_rathole
configure_service
manage_service

if verify_installation; then
    echo -e "\n${GREEN}🎉 Congratulations! Rathole has been successfully installed with enhanced logging.${RESET}"
    echo ""
    echo "Logging Locations:"
    echo " • stdout: ${STDOUT_LOG}"
    echo " • stderr: ${STDERR_LOG}"
    echo " • Access: ${ACCESS_LOG}"
    echo " • Error:  ${ERROR_LOG}"
else
    echo -e "${RED}⚠️  Installation verification failed. Please review the error messages above.${RESET}"
fi
