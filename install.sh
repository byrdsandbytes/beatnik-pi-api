#!/bin/bash
#
# This script automates the local development setup for the Beatnik Pi Provisioning UI & API.
# It performs the following steps:
# 1. Installs frontend (Ionic/Angular) dependencies.
# 2. Installs backend (Python/Flask) dependencies in a virtual environment.
# 3. Builds the production-ready frontend application.
#

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Frontend Setup (portal-ui) ---
echo "--- Setting up Frontend (portal-ui) ---"
echo "Navigating to portal-ui directory..."
cd portal-ui

echo "Installing npm dependencies..."
npm install

echo "Frontend dependencies installed successfully."
cd ..
echo "---------------------------------------"
echo ""


# --- Backend Setup (portal-api) ---
echo "--- Setting up Backend (portal-api) ---"
echo "Navigating to portal-api directory..."
cd portal-api

echo "Creating Python virtual environment..."
python3 -m venv venv

echo "Activating virtual environment and installing dependencies..."
# Note: Activating the venv in a script requires this syntax.
source venv/bin/activate
pip install -r requirements.txt
deactivate

echo "Backend dependencies installed successfully."
cd ..
echo "--------------------------------------"
echo ""


# --- Build Frontend Application ---
echo "--- Building Frontend Application ---"
echo "Navigating to portal-ui directory..."
cd portal-ui

echo "Building Ionic/Angular app for production..."
ionic build --prod

echo "Frontend build complete. Static files are in dist/portal-ui."
cd ..
echo "-----------------------------------"
echo ""


# --- Final Instructions ---
echo "✅ Local development setup is complete!"
echo ""
echo "To run the full application:"
echo "1. Activate the backend virtual environment:"
echo "   source portal-api/venv/bin/activate"
echo ""
echo "2. Start the Flask server from the repository root:"
echo "   python3 portal-api/beatnik-api.py"
echo ""
echo "3. Open your browser to http://localhost:5001"
echo ""
