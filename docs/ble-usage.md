# RPi Wi-Fi BLE Service: API Documentation

This document provides a complete guide for developers to interact with the BLE service from the nksan/Rpi-SetWiFi-viaBluetooth repository. The primary use case is building a custom mobile application (e.g., with Angular/Capacitor) to configure a Raspberry Pi's Wi-Fi connection.

![Mobile App to Raspberry Pi](https://placehold.co/600x300/3B82F6/FFFFFF?text=Mobile+App+%E2%86%94+Raspberry+Pi)

## Table of Contents

- [Core Concepts](#1-core-concepts)
- [Prerequisites](#2-prerequisites)  
- [BLE Service Profile (UUIDs)](#3-ble-service-profile-uuids)
- [Data Models & Payloads](#4-data-models--payloads)
- [Error Handling & Best Practices](#5-error-handling--best-practices)
- [Angular & Capacitor Implementation](#6-angular--capacitor-implementation)
  - [Angular Service (ble-wifi.service.ts)](#angular-service-ble-wifiservicets)
  - [Component Usage Example](#component-usage-example)

## 1. Core Concepts

The Raspberry Pi hosts a GATT (Generic Attribute Profile) service that exposes several functions ("characteristics") for Wi-Fi management. The standard application workflow is:

1. **Scan**: The app scans for BLE devices advertising the specific Service UUID.
2. **Connect**: The app establishes a connection to the discovered Pi.
3. **Interact**: The app subscribes to status notifications, reads the Wi-Fi list, and writes credentials or commands.
4. **Disconnect**: The app terminates the connection when done.

## 2. Prerequisites

To integrate this API, your mobile app project requires:

### Capacitor
Your framework (Angular, React, Vue) must be configured to use Capacitor.

### Capacitor BLE Plugin
The official community plugin for Bluetooth Low Energy must be installed:

```bash
npm install @capacitor-community/bluetooth-le
npx cap sync
```

### Platform Permissions
You must configure native permissions for Bluetooth access.

**iOS (Info.plist):**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Our app uses Bluetooth to find and configure your Raspberry Pi.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Our app uses Bluetooth to connect to your Raspberry Pi.</string>
```

**Android (AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## 3. BLE Service Profile (UUIDs)

These are the core identifiers for the service. All UUIDs are essential for communication.

| Name | UUID | Permissions | Description |
|------|------|-------------|-------------|
| Main Service | `0000a000-0000-1000-8000-00805f9b34fb` | - | The primary service advertised by the Pi. |
| Wi-Fi List | `0000a001-0000-1000-8000-00805f9b34fb` | Read | Returns a JSON array of available Wi-Fi networks. |
| Write Wi-Fi | `0000a002-0000-1000-8000-00805f9b34fb` | Write | Accepts a JSON object with Wi-Fi credentials. |
| Status | `0000a003-0000-1000-8000-00805f9b34fb` | Read, Notify | Provides real-time status updates (e.g., "Connecting", "Success"). |
| Write Command | `0000a004-0000-1000-8000-00805f9b34fb` | Write | Accepts a JSON object with a command to execute. |

## 4. Data Models & Payloads

All data is transmitted as UTF-8 encoded strings. Using TypeScript interfaces is highly recommended for type safety.

### Data Models (Interfaces)

```typescript
// Structure for an object in the Wi-Fi list array
export interface WifiNetwork {
  ssid: string;
  rssi: number;
  known: boolean;
}

// Structure for writing new credentials
export interface WifiCredentials {
  ssid: string;
  psk: string; // Password. Use an empty string for open networks.
}

// Structure for sending a command
export interface WifiCommand {
  ssid: string;
  cmd: 'connect' | 'disconnect'; // Supported commands
}
```

### Read Payloads

**Wi-Fi List (`...a001`)**: A JSON string that can be parsed into a `WifiNetwork[]` array.

```json
[
  {"ssid": "MyHomeNetwork", "rssi": -55, "known": true},
  {"ssid": "NeighborNet", "rssi": -78, "known": false}
]
```

## 5. Error Handling & Best Practices

- **Use Notifications**: Subscribe to the Status characteristic (`...a003`) immediately after connecting to receive real-time feedback. This is more efficient than polling.

- **Connection Guard**: Always check if a device is connected before attempting to read or write data.

- **Scan Timeout**: Implement a timeout for your BLE scan (e.g., 10-15 seconds) to prevent infinite scanning and battery drain.

- **UI Feedback**: Clearly communicate the connection state (Scanning, Connecting, Connected, Failed, Success) to the user, ideally using the real-time status notifications.

- **Proper Disconnect**: Always disconnect from the device when the app is closed or the user navigates away to release the Bluetooth resource.

- **JSON Validation**: Wrap your `JSON.parse()` calls in a try...catch block to gracefully handle any malformed data received from the device.

## 6. Angular & Capacitor Implementation

### Angular Service (ble-wifi.service.ts)

This complete service encapsulates all BLE logic, providing a clean, reusable API for your components.

```typescript

import { Injectable, NgZone } from '@angular/core';
import { BleClient, BleDevice, numbersToDataView, dataViewToText } from '@capacitor-community/bluetooth-le';
import { Observable, Subject } from 'rxjs';

// --- Data Models ---
export interface WifiNetwork {
  ssid: string;
  rssi: number;
  known: boolean;
}
export interface WifiCredentials {
  ssid: string;
  psk: string;
}
export interface WifiCommand {
  ssid: string;
  cmd: 'connect' | 'disconnect';
}

// --- UUID Constants ---
const RPI_WIFI_SERVICE = '0000a000-0000-1000-8000-00805f9b34fb';
const WIFI_LIST_CHARACTERISTIC = '0000a001-0000-1000-8000-00805f9b34fb';
const WRITE_WIFI_CHARACTERISTIC = '0000a002-0000-1000-8000-00805f9b34fb';
const STATUS_CHARACTERISTIC = '0000a003-0000-1000-8000-00805f9b34fb';
const WRITE_COMMAND_CHARACTERISTIC = '0000a004-0000-1000-8000-00805f9b34fb';

@Injectable({
  providedIn: 'root'
})
export class BleWifiService {
  private connectedDevice: BleDevice | null = null;
  private statusUpdates = new Subject<string>();
  public statusUpdates$ = this.statusUpdates.asObservable();

  constructor(private ngZone: NgZone) {}

  async initialize(): Promise<void> {
    await BleClient.initialize();
  }

  scanForPi(): Observable<BleDevice> {
    return new Observable(subscriber => {
      BleClient.requestLEScan({ services: [RPI_WIFI_SERVICE] }, (result) => {
        if (result.device) {
          this.ngZone.run(() => subscriber.next(result.device));
        }
      }).catch(err => this.ngZone.run(() => subscriber.error(err)));

      setTimeout(async () => {
        await BleClient.stopLEScan();
        this.ngZone.run(() => subscriber.complete());
      }, 10000); // 10-second timeout
    });
  }

  async connect(device: BleDevice): Promise<void> {
    await BleClient.connect(device.deviceId);
    this.connectedDevice = device;
    await this.startStatusNotifications(); // Start listening for status updates
  }

  async disconnect(): Promise<void> {
    if (this.connectedDevice) {
      await BleClient.disconnect(this.connectedDevice.deviceId);
      this.connectedDevice = null;
    }
  }

  async getWifiList(): Promise<WifiNetwork[]> {
    if (!this.connectedDevice) throw new Error('Not connected');
    const result = await BleClient.read(this.connectedDevice.deviceId, RPI_WIFI_SERVICE, WIFI_LIST_CHARACTERISTIC);
    try {
      return JSON.parse(dataViewToText(result));
    } catch {
      return []; // Return empty array on parse error
    }
  }

  async setWifiCredentials(credentials: WifiCredentials): Promise<void> {
    if (!this.connectedDevice) throw new Error('Not connected');
    const payload = JSON.stringify(credentials);
    await BleClient.write(this.connectedDevice.deviceId, RPI_WIFI_SERVICE, WRITE_WIFI_CHARACTERISTIC, this.stringToDataView(payload));
  }

  async sendWifiCommand(command: WifiCommand): Promise<void> {
    if (!this.connectedDevice) throw new Error('Not connected');
    const payload = JSON.stringify(command);
    await BleClient.write(this.connectedDevice.deviceId, RPI_WIFI_SERVICE, WRITE_COMMAND_CHARACTERISTIC, this.stringToDataView(payload));
  }

  private async startStatusNotifications(): Promise<void> {
    if (!this.connectedDevice) throw new Error('Not connected');
    await BleClient.startNotifications(
      this.connectedDevice.deviceId,
      RPI_WIFI_SERVICE,
      STATUS_CHARACTERISTIC,
      (value) => {
        this.ngZone.run(() => {
          this.statusUpdates.next(dataViewToText(value));
        });
      }
    );
  }

  private stringToDataView(str: string): DataView {
    return numbersToDataView(Array.from(new TextEncoder().encode(str)));
  }
}
```

### Component Usage Example

```typescript
import { Component, OnDestroy } from '@angular/core';
import { BleWifiService, WifiNetwork } from './ble-wifi.service';
import { BleDevice } from '@capacitor-community/bluetooth-le';
import { finalize, Subscription } from 'rxjs';

@Component({
  selector: 'app-wifi-connector',
  template: `
    <!-- Connection UI -->
    <p>Live Status: {{ liveStatus || 'Disconnected' }}</p>
    <!-- Wi-Fi List and Interaction UI -->
  `
})
export class WifiConnectorComponent implements OnDestroy {
  isScanning = false;
  isConnected = false;
  liveStatus = '';
  foundDevices: BleDevice[] = [];
  wifiNetworks: WifiNetwork[] = [];

  private statusSub: Subscription;

  constructor(private bleWifiService: BleWifiService) {}

  // This would be called in a relevant lifecycle hook like ngOnInit
  async setup() {
    await this.bleWifiService.initialize();
    this.statusSub = this.bleWifiService.statusUpdates$.subscribe(status => {
      this.liveStatus = status;
      // Handle status changes, e.g., show success message
      if (status.includes('Success')) {
        console.log('Wi-Fi connection successful!');
      }
    });
  }
  
  startScan() {
    this.isScanning = true;
    this.foundDevices = [];
    this.bleWifiService.scanForPi().pipe(
      finalize(() => this.isScanning = false)
    ).subscribe(device => {
      if (!this.foundDevices.find(d => d.deviceId === device.deviceId)) {
        this.foundDevices.push(device);
      }
    });
  }

  async connect(device: BleDevice) {
    try {
      this.liveStatus = `Connecting to ${device.name || 'Pi'}...`;
      await this.bleWifiService.connect(device);
      this.isConnected = true;
      this.wifiNetworks = await this.bleWifiService.getWifiList();
    } catch (error) {
      console.error('Failed to connect', error);
      this.liveStatus = 'Connection failed';
    }
  }

  disconnect() {
    this.bleWifiService.disconnect();
    this.isConnected = false;
    this.liveStatus = 'Disconnected';
  }
  
  ngOnDestroy() {
    this.statusSub?.unsubscribe();
    this.bleWifiService.disconnect();
  }
}
```
