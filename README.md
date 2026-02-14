<!-- <p align="center">
  <img src="https://raw.githubusercontent.com/olildu/HotDrop/HotDrop-Mobile/assets/images/app_logo/app_logo_transparent.png" 
       alt="HotDrop Logo" 
       width="180">
</p> -->

# 🚀 HotDrop: Cross-Platform P2P File Sharing

A high-performance, decentralized file-sharing ecosystem built with **Flutter**. HotDrop enables seamless, high-speed data transfer between **Android** and **Windows** devices using custom P2P protocols without requiring an active internet connection.

<p align="center">
  <a href="https://x.com/olildu">
    <img src="https://img.shields.io/twitter/follow/olildu.svg?style=social&label=Follow" alt="Twitter">
  </a>
  &nbsp;&nbsp;
  <a href="https://www.linkedin.com/in/ebinsanthosh/">
    <img src="https://img.shields.io/badge/LinkedIn-Connect-0A66C2?logo=linkedin&logoColor=white" alt="LinkedIn">
  </a>
</p>

## 🌟 Project Highlights & Technical Differentiators

This project demonstrates advanced socket programming, native platform integration, and a custom-built distributed sharing architecture.

| Feature | Technical Implementation | Engineering Value Demonstrated |
| :--- | :--- | :--- |
| **P2P Networking** | **TCP Sockets** (Port 42069) for real-time control data | Low-latency bi-directional communication, custom handshake logic |
| **High-Speed Transfer** | **Internal HTTP Server** hosting with Binary Streams | High-throughput data piping, efficient memory management |
| **Platform Discovery** | **Native MethodChannels** for Android WiFi Direct 6 | Deep integration with hardware-level networking APIs |
| **Monorepo Architecture** | Unified management of **Desktop (Server)** and **Mobile (Client)** | Scalable codebase for multi-environment ecosystems |

## 🧱 Architecture Overview: Desktop-Mobile Sync

The project utilizes a **Server-Client architecture** where the Desktop acts as a stable hub and the Mobile device acts as a portable file host.

### **Desktop Environment (`apps/desktop`)**
- Acts as the **Socket Server**, listening for incoming peer connections on port 42069.
- Manages global state for connected peers and shared metadata using the **Provider** pattern.
- Facilitates high-speed file requests from mobile clients through dedicated HTTP handling.

### **Mobile Environment (`apps/mobile`)**
- Implements **WiFi Direct** for peer discovery and automated IP handshakes via Kotlin MethodChannels.
- Hosts an **Internal Web Server** to pipe local files as binary streams directly to the PC client.
- Synchronizes contacts and real-time messages across the established socket tunnel.

## ⚙️ Core Modules & Components

| Module | Purpose | Key Files |
| :--- | :--- | :--- |
| **Connection Service** | Manages TCP `ServerSocket` and `Socket.connect` logic | `connection_services.dart` |
| **File Hosting** | Converts local file paths into streamable HTTP URLs | `file_hosting_services.dart` |
| **Data Parser** | Decodes socket bytes into structured UI updates (JSON) | `data_services.dart` |
| **Native Discovery** | Interfaces with Android-specific WiFi Direct APIs | `MainActivity.kt` |

## 🛠️ Development Setup

Requires **Flutter 3.24.x** or higher.

### **Installation**

1. **Clone the Repository:**
   ```bash
   git clone [https://github.com/olildu/HotDrop.git](https://github.com/olildu/HotDrop.git)
   cd HotDrop
   ```
2. **Run Desktop App (Windows)**
    ```bash
    cd apps/desktop
    flutter pub get
    flutter run -d windows
    ```
3. **Run Mobile App (Android)**
    ```bash
    cd apps/mobile
    flutter pub get
    flutter run -d android
    ```

### 📱 Ecosystem Logic

HotDrop is designed for **LAN/P2P environments**, enabling high-speed data exchange without external internet dependencies. To establish a secure peer-to-peer connection:

1.  **Initialize Host:** Launch HotDrop on your Windows PC. The system automatically initializes a **TCP listener on Port 42069**.
2.  **Discover Peers:** Open HotDrop on your Android device and initiate a scan. The app utilizes the **native WiFi Direct interface** to discover active desktop nodes.
3.  **Seamless Sharing:** Once the handshake is complete, metadata, contacts, and files are shared instantly via **binary streams** with **zero bandwidth consumption**.



