import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

// Define a type for the network list for better code quality
export interface WifiNetwork {
  ssid: string;
  signal: string;
}

@Injectable({
  providedIn: 'root'
})
export class WifiService {
  // The API is served from the same host, so we use a relative path.
  private readonly API_URL = '/api';

  constructor(private http: HttpClient) { }

  /**
   * Triggers a scan on the Pi and returns a list of available networks.
   * @returns An Observable array of WifiNetwork objects.
   */
  scanNetworks(): Observable<WifiNetwork[]> {
    return this.http.get<WifiNetwork[]>(`${this.API_URL}/scan`);
  }

  /**
   * Sends the selected network's credentials to the Pi to initiate a connection.
   * @param ssid The SSID of the network to connect to.
   * @param password The password for the network.
   * @returns An Observable with the connection status.
   */
  connect(ssid: string, password: string): Observable<any> {
    return this.http.post(`${this.API_URL}/connect`, { ssid, password });
  }
}
