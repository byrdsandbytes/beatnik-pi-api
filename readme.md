# Beatnik Pi API & Provisioning UI

This repository contains the self-contained Wi-Fi provisioning service for the Beatnik Pi project. It includes a lightweight Python/Flask backend and an Ionic/Angular frontend.

The service's purpose is to create a temporary Wi-Fi hotspot when a Beatnik player cannot connect to a known network. A user can connect to this hotspot, use the web interface to scan for their home network, and submit their credentials.

## Project Structure

This repository is a monorepo containing three main parts:

-   **`portal-ui/`**: The Ionic/Angular frontend application that the user interacts with.
-   **`portal-api/`**: The Python/Flask backend that serves the UI, scans for networks, and handles the connection logic via `nmcli`.
-   **`config/`**: A collection of system configuration files (`.service`, `.conf`) used by the main `beatnik-pi` installer to set up the environment on the Raspberry Pi.

## Architecture

1.  **`Nodogsplash`** (installed separately by `beatnik-pi`) acts as the captive portal gateway.
2.  When a new device connects to the "Beatnik-Setup" hotspot, `Nodogsplash` redirects the user's browser to the Flask API.
3.  The Flask API (`beatnik-api.py`) serves the compiled Ionic application from the `dist/portal-ui` directory.
4.  The Ionic App (running in the user's browser) makes API calls to the Flask server (`/api/scan`, `/api/connect`) to manage the Wi-Fi connection.

## Local Development Setup

An automated script is provided to handle the entire local setup.

### Automated Local Setup

The `install.sh` script will:
1.  Install all frontend `npm` dependencies.
2.  Create a Python virtual environment for the backend.
3.  Install all backend `pip` dependencies.
4.  Build the production version of the frontend app.

To run the script:
```bash
# Make the script executable
chmod +x install.sh

# Run the installer
./install.sh
```
After the script finishes, follow the on-screen instructions to start the server.

### Manual Local Setup

If you prefer to set up the environment manually, follow these steps.

#### Prerequisites

-   Node.js and npm
-   Ionic CLI (`npm install -g @ionic/cli`)
-   Angular CLI (`npm install -g @angular/cli`)
-   Python 3 and pip

#### 1. Set Up the Frontend (`portal-ui`)

The UI can be developed and tested independently of the Raspberry Pi.

```bash
# Navigate to the UI directory
cd portal-ui

# Install dependencies
npm install

# Run the local development server
ionic serve
```

This will open a browser window at `http://localhost:8100`. The API calls will fail, which is expected.

#### 2. Set Up the Backend (`portal-api`)

The backend serves the compiled frontend and provides the API.

```bash
# Navigate to the API directory
cd portal-api

# (Optional, but recommended) Create and activate a Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### 3. Build and Serve the Full Application

To test the complete flow locally (without real `nmcli` commands):

1.  **Build the Ionic App**: From the `portal-ui` directory, run the build command. This will generate the static files in the `dist/portal-ui` folder.

    ```bash
    # Inside portal-ui/
    ionic build --prod
    ```

2.  **Run the Flask Server**: From the repository root, start the Python server. It will automatically find and serve the compiled files from the `dist/` folder.

    ```bash
    # From the repository root
    python3 portal-api/beatnik-api.py
    ```

Open your browser to `http://localhost:5001`. You should see your full Ionic application running. The API calls for scanning and connecting will fail because `nmcli` is not available, but you can test the UI flow.

## Deployment to Raspberry Pi

The primary deployment method is via the main `beatnik-pi` installer. However, a script is provided for manual installation or testing on a device.

### Automated Pi Setup (Manual Installation)

The `setup_pi.sh` script automates the deployment process on a target Raspberry Pi. It will:

1.  Install all required system and Python dependencies.
2.  Copy the `systemd` and `nodogsplash` configuration files to their correct locations.
3.  Update the service files with the correct paths.
4.  Enable the services to start on boot.

To run the script on the Pi (assuming the repo is at `/opt/beatnik-portal`):
```bash
# Make the script executable
sudo chmod +x /opt/beatnik-portal/setup_pi.sh

# Run the setup script
sudo /opt/beatnik-portal/setup_pi.sh
```
After the script finishes, reboot the Pi to apply the changes.

### Manual Deployment Steps

This repository is not intended to be run directly by the end-user. Instead, the `beatnik-pi` installer script (or the automated script above) will perform the following actions:

1.  Clone this repository to `/opt/beatnik-portal` on the Pi.
2.  Install the required system dependencies (Python, Flask, Nodogsplash, etc.).
3.  Copy the configuration files from the `config/` directory to their respective system locations (e.g., `/etc/systemd/system/`).
4.  Update paths within the service files to point to the correct locations inside `/opt/beatnik-portal/`.
5.  Enable and start the `systemd` services.