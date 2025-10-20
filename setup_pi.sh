#!/bin/bash
#
# This script automates the deployment and setup of the Beatnik Pi Provisioning
# service on a Raspberry Pi. It is intended to be run on the target device.
#
# It performs the following actions:
# 1. Checks for root privileges.
# 2. Installs system-level dependencies (python, pip, network-manager, nodogsplash).
# 3. Installs required Python packages.
# 4. Copies systemd service and nodogsplash configuration files.
# 5. Updates paths in the service file to match the deployment directory.
# 6. Enables the new services to start on boot.
#

# --- Configuration ---
# The location where this repository is expected to be cloned on the Pi.
# The beatnik-pi installer clones it here.
DEPLOY_DIR="/opt/beatnik-portal"
SUDO_USER=${SUDO_USER:-$(whoami)}

# --- Sanity Checks ---
# Exit immediately if a command exits with a non-zero status.
set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root or with sudo." >&2
  exit 1
fi

echo "--- Beatnik Pi Provisioning Setup ---"
echo "Running setup for deployment directory: $DEPLOY_DIR"
echo ""

# --- Dependency Installation ---
echo "--- Installing System Dependencies ---"
apt-get update
apt-get install -y python3 python3-pip python3-venv network-manager nodogsplash
echo "System dependencies installed."
echo "------------------------------------"
echo ""

echo "--- Installing Python Dependencies ---"
# Install Python packages from the backend's requirements file.
# Using pip from the system's python3 installation.
python3 -m pip install -r "$DEPLOY_DIR/portal-api/requirements.txt"
echo "Python dependencies installed."
echo "------------------------------------"
echo ""

# --- Configuration File Setup ---
echo "--- Setting up Configuration Files ---"

# Copy the systemd service file
if [ -f "$DEPLOY_DIR/config/beatnik-portal.service" ]; then
    echo "Copying beatnik-portal.service to /etc/systemd/system/..."
    cp "$DEPLOY_DIR/config/beatnik-portal.service" /etc/systemd/system/beatnik-portal.service

    # Update the paths in the service file to point to the DEPLOY_DIR
    echo "Updating paths in service file..."
    sed -i "s|/path/to/repo|$DEPLOY_DIR|g" /etc/systemd/system/beatnik-portal.service
else
    echo "WARNING: beatnik-portal.service not found in config/. Skipping."
fi

# Copy the nodogsplash configuration file
if [ -f "$DEPLOY_DIR/config/nodogsplash.conf" ]; then
    echo "Copying nodogsplash.conf to /etc/nodogsplash/..."
    cp "$DEPLOY_DIR/config/nodogsplash.conf" /etc/nodogsplash/nodogsplash.conf
else
    echo "WARNING: nodogsplash.conf not found in config/. Skipping."
fi

echo "Configuration files copied and updated."
echo "--------------------------------------"
echo ""


# --- Service Management ---
echo "--- Enabling Systemd Services ---"
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling beatnik-portal service..."
systemctl enable beatnik-portal.service

echo "Enabling nodogsplash service..."
systemctl enable nodogsplash.service

echo "Services enabled."
echo "-------------------------------"
echo ""


# --- Final Instructions ---
echo "✅ Deployment setup is complete!"
echo ""
echo "A reboot is required to apply all changes and start the new services."
echo "Run 'sudo reboot' to restart your Raspberry Pi."
echo ""
