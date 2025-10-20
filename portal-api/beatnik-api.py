import subprocess
import json
import os
from flask import Flask, jsonify, request, send_from_directory

# --- Configuration ---
# The installer will set this env var to "/opt/beatnik-portal/ui"
# For local testing, it falls back to the "dist" folder.
UI_PATH = os.environ.get('PORTAL_UI_PATH', 'dist/portal-ui')

app = Flask(__name__, static_folder=UI_PATH)

# --- API Endpoints ---
@app.route("/api/scan")
def api_scan():
    try:
        subprocess.run(["sudo", "nmcli", "device", "wifi", "rescan"], check=True, timeout=5)
        output = subprocess.check_output(
            ["sudo", "nmcli", "--terse", "--fields", "SSID,SIGNAL", "device", "wifi", "list", "--rescan", "no"],
            encoding='utf-8'
        ).split('\n')

        networks = []
        seen_ssids = set()
        for line in output:
            if line.strip():
                parts = line.split(':')
                if len(parts) >= 2:
                    ssid = parts[0]
                    signal = parts[1]
                    if ssid and ssid not in seen_ssids:
                        networks.append({"ssid": ssid, "signal": signal})
                        seen_ssids.add(ssid)

        return jsonify(networks)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/connect", methods=['POST'])
def api_connect():
    data = request.get_json()
    ssid = data.get('ssid')
    password = data.get('password')

    if not ssid or not password:
        return jsonify({"error": "Missing SSID or password"}), 400

    try:
        cmd = ["sudo", "nmcli", "device", "wifi", "connect", ssid, "password", password]
        subprocess.run(cmd, check=True, timeout=20)
        return jsonify({"status": "success"})
    except Exception as e:
        return jsonify({"error": "Failed to connect. Check password?"}), 500

# --- Angular Catch-All Route ---
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_angular_app(path):
    if path != "" and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    else:
        return send_from_directory(app.static_folder, 'index.html')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5001)
