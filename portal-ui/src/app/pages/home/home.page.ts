import { Component } from '@angular/core';
import { finalize } from 'rxjs';
import { WifiNetwork, WifiService } from 'src/app/services/wifi';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
  standalone: false,
})
export class HomePage {

 // UI State Management
  isScanning = false;
  scanCompleted = false;
  isConnecting = false;
  
  // Data
  networks: WifiNetwork[] = [];
  selectedSsid: string = '';
  password = '';

  // Feedback
  feedbackMessage = '';
  feedbackSuccess = false;

  constructor(private wifiService: WifiService) {}

  onScan() {
    this.isScanning = true;
    this.wifiService.scanNetworks().pipe(
      finalize(() => this.isScanning = false)
    ).subscribe({
      next: (data) => {
        this.networks = data;
        // Pre-select the first network if available
        if (this.networks.length > 0) {
          this.selectedSsid = this.networks[0].ssid;
        }
        this.scanCompleted = true;
      },
      error: (err) => {
        this.isConnecting = true; // Use connecting state to show feedback
        this.feedbackMessage = 'Error scanning for networks. Please refresh and try again.';
        this.feedbackSuccess = false;
      }
    });
  }

  onConnect() {
    if (!this.selectedSsid || !this.password) {
      return;
    }

    this.isConnecting = true;
    this.feedbackMessage = ''; // Clear previous messages
    this.feedbackSuccess = false;

    this.wifiService.connect(this.selectedSsid, this.password).subscribe({
      next: (response) => {
        this.feedbackMessage = `Success! Your Beatnik player is now connecting to "${this.selectedSsid}". You can close this page and reconnect your device to your home Wi-Fi.`;
        this.feedbackSuccess = true;
      },
      error: (err) => {
        this.feedbackMessage = err.error?.error || 'Failed to connect. Please check your password and try again.';
        this.feedbackSuccess = false;
      }
    });
  }

  reset() {
    this.isConnecting = false;
    this.scanCompleted = false;
    this.feedbackMessage = '';
    this.password = '';
  }
}