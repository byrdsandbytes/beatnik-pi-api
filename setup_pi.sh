#!/bin/bash
#
# This script automates the deployment and setup of the Beatnik Pi Provisioning
# service on a Raspberry Pi. It is intended to be run from the `beatnik-pi` repo.
#
# It performs the following actions:
# 1. Checks for root privileges.
# 2. Installs system-level dependencies.
# 3. Compiles and installs Nodogsplash from source.
# 4. Clones the beatnik-pi-api repository.
# 5. Copies and configures all necessary system files.
# 6. Enables the services to start on boot.
#

# --- Configuration ---
DEPLOY_DIR="/opt/beatnik-portal"

# --- Sanity Checks ---
set -e
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root or with sudo." >&2
  exit 1
fi

echo "--- Beatnik Pi Provisioning Setup ---"
echo ""

# --- 1. Dependency Installation ---
echo "--- Installing System Dependencies ---"
apt-get update
# <<< CHANGE: Added build tools, removed nodogsplash from this line
apt-get install -y \
    python3 python3-pip python3-venv \
    network-manager git \
    build-essential libmicrohttpd-dev libjson-c-dev
echo "System dependencies installed."
echo "------------------------------------"
echo ""

# --- 2. Compile and Install Nodogsplash ---
# <<< CHANGE: This entire section is new and critical
echo "--- Compiling and Installing Nodogsplash from Source ---"
# Use /tmp for temporary build files
cd /tmp
git clone https://github.com/nodogsplash/nodogsplash.git
cd nodogsplash
make
make install
# Clean up the temporary source files
cd /
rm -rf /tmp/nodogsplash
echo "Nodogsplash installed successfully."
echo "------------------------------------"
echo ""

# --- 3. Clone and Install Beatnik Provisioning Service ---
echo "--- Cloning beatnik-pi-api Repository ---"
# Remove old version if it exists
if [ -d "$DEPLOY_DIR" ]; then
    rm -rf "$DEPLOY_DIR"
fi
# Clone into the permanent deployment directory
git clone https://github.com/byrdsandbytes/beatnik-pi-api.git "$DEPLOY_DIR"
echo "Repository cloned to $DEPLOY_DIR"
echo "------------------------------------"
echo ""

echo "--- Installing Python Dependencies ---"
python3 -m pip install -r "$DEPLOY_DIR/portal-api/requirements.txt"
echo "Python dependencies installed."
echo "------------------------------------"
echo ""

# --- 4. Configuration File Setup ---
echo "--- Setting up Configuration Files ---"
CONFIG_SRC="$DEPLOY_DIR/config"

# Copy NetworkManager config to enable internal dnsmasq
echo "Copying NetworkManager.conf..."
cp "$CONFIG_SRC/NetworkManager.conf" /etc/NetworkManager/

# <<< CHANGE: Add the DNS hijack rule for the captive portal (iOS fix)
echo "Creating DNS hijack rule for captive portal..."
mkdir -p /etc/NetworkManager/dnsmasq.d/
echo "address=/#/192.168.42.1" > /etc/NetworkManager/dnsmasq.d/captive-portal.conf

# Copy Nodogsplash config
echo "Copying nodogsplash.conf..."
cp "$CONFIG_SRC/nodogsplash.conf" /etc/nodogsplash/

# Copy the "brain" script and make it executable
echo "Copying beatnik-network-check.sh..."
cp "$CONFIG_SRC/beatnik-network-check.sh" /usr/local/bin/
chmod +x /usr/local/bin/beatnik-network-check.sh

# Copy all systemd service files
echo "Copying systemd service files..."
cp "$CONFIG_SRC/beatnik-api.service" /etc/systemd/system/
cp "$CONFIG_SRC/beatnik-network.service" /etc/systemd/system/
cp "$CONFIG_SRC/nodogsplash.service" /etc/systemd/system/

# Update the paths in the service file to point to the DEPLOY_DIR
echo "Updating paths in beatnik-api.service..."
sed -i "s|/opt/beatnik-portal|$DEPLOY_DIR|g" /etc/systemd/system/beatnik-api.service
# Run API as root to have permission for nmcli
sed -i "s|User=beatnik|User=root|g" /etc/systemd/system/beatnik-api.service

echo "Configuration files copied and updated."
echo "--------------------------------------"
echo ""

# --- 5. Service Management ---
echo "--- Enabling Systemd Services ---"
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling beatnik-api.service..."
systemctl enable beatnik-api.service

echo "Enabling nodogsplash.service..."
systemctl enable nodogsplash.service

echo "Enabling beatnik-network.service (the 'brain')..."
systemctl enable beatnik-network.service

echo "Services enabled."
echo "-------------------------------"
echo ""

# --- Final Instructions ---
echo "✅ Deployment setup is complete!"
echo ""
echo "A reboot is required to apply all changes and start the new services."
echo "Run 'sudo reboot' to restart your Raspberry Pi."
echo ""