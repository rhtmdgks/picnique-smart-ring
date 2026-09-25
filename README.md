# Picnique Smart Ring

Picnique Smart Ring is a Flutter-based companion application for a Bluetooth Low Energy smart ring, combining **health monitoring, activity and sleep tracking, background synchronization, and rosary-focused wellness features** in a single wearable platform.

The project includes both the user-facing mobile application and a custom BLE communication layer for compatible Colmi / Yawell / QRing RF03-based smart rings.

## Overview

The application is designed to connect directly to compatible smart rings without relying on a proprietary OEM native SDK.

It communicates with the ring over BLE, retrieves sensor and activity data, stores measurements locally, and presents health-related information through a mobile interface.

The platform also includes rosary and Catholic-oriented features, extending the smart ring beyond general health tracking into a broader wellness experience.

## Core Features

### Smart Ring Connectivity

* Bluetooth Low Energy device discovery
* Smart ring connection and reconnection
* Battery monitoring
* Device capability detection
* Command queue and packet handling
* Background BLE synchronization
* Automatic health measurements
* Ring state and connection management

### Health Monitoring

* Heart rate monitoring
* Blood oxygen saturation (SpO₂)
* Stress measurements
* HRV support for compatible devices
* Activity tracking
* Steps
* Calories
* Distance
* Sleep data synchronization
* Historical health data storage

### Background Services

* Periodic ring data synchronization
* Automatic measurement scheduling
* Background data import
* Connection keep-alive handling
* Battery notifications
* Health data refresh notifications
* iOS Live Activity integration

### Rosary & Catholic Features

* Rosary prayer interface
* Rosary mysteries
* Prayer statistics
* Catholic information
* Rosary-oriented activity tracking
* Catholic wellness experiences
* WYD community interface

## Tech Stack

| Area                 | Technology                  |
| -------------------- | --------------------------- |
| Mobile Client        | Flutter / Dart              |
| Bluetooth            | `flutter_blue_plus`         |
| Local Database       | Drift / SQLite              |
| State Management     | Provider                    |
| Charts               | `fl_chart`                  |
| Notifications        | Flutter Local Notifications |
| Persistence          | SharedPreferences           |
| Markdown             | Flutter Markdown            |
| Platforms            | iOS / Android               |
| Device Communication | Custom BLE protocol stack   |

## Architecture

```text
Flutter Application
│
├── UI / Screens
│   ├── Health Dashboard
│   ├── Ring Connection
│   ├── Monitoring Settings
│   ├── Heart Rate
│   ├── SpO₂
│   ├── Stress
│   ├── Activity
│   ├── Sleep
│   └── Rosary / Catholic Features
│
├── Application Services
│   ├── Ring Connection
│   ├── Measurements
│   ├── Background Sync
│   ├── Battery Monitoring
│   ├── Notifications
│   └── Health Data Aggregation
│
├── Local Storage
│   └── Drift / SQLite
│
└── Ring Protocol Layer
    ├── Transport
    ├── Command Queue
    ├── Packet Codec
    ├── Commands
    ├── Capability Detection
    └── Ring Repository
            │
            ▼
      Bluetooth Low Energy
            │
            ▼
       Compatible Smart Ring
```

## BLE Protocol Layer

The repository includes a custom Dart-based BLE protocol implementation under:

```text
lib/ring/
```

The implementation communicates directly with compatible RF03-family devices using `flutter_blue_plus`.

### Supported Communication

The protocol layer includes:

* GATT service discovery
* Main command channel
* Big-data channel
* Packet encoding and decoding
* Command serialization
* Device capability probing
* Measurement parsing
* Historical data retrieval

### Supported Device Families

The current implementation targets compatible devices from the Colmi / Yawell / QRing ecosystem, including RF03-based models.

Known compatibility includes variants such as:

```text
R02
R03
R04
R05
R06
R07
R08
R09
R10
R11
R12
H59 / compatible OEM variants
```

Actual capabilities vary depending on the hardware model and firmware.

## Supported Ring Data

Depending on device capabilities, the protocol layer supports or probes for:

| Data / Feature      | Support          |
| ------------------- | ---------------- |
| Battery             | Supported        |
| Heart Rate          | Supported        |
| Realtime Heart Rate | Supported        |
| Heart Rate History  | Supported        |
| SpO₂                | Supported        |
| Stress              | Supported        |
| Steps               | Supported        |
| Calories            | Supported        |
| Distance            | Supported        |
| Sleep               | Supported        |
| HRV                 | Device-dependent |
| Temperature         | Device-dependent |
| Raw Accelerometer   | Device-dependent |

Some devices expose additional functionality depending on firmware and OEM configuration.

## Project Structure

```text
lib/
├── _mock/          # Development and mock data
├── assets/         # Application assets and fonts
├── core/           # Core constants and shared application logic
├── db/             # Drift database and persistence
├── providers/      # Application state management
├── ring/           # BLE smart-ring protocol implementation
│   ├── capability/
│   ├── codec/
│   ├── commands/
│   ├── example/
│   ├── features/
│   ├── repository/
│   └── transport/
├── screens/        # Application screens
│   ├── auth/
│   ├── community/
│   ├── layouts/
│   ├── modes/
│   └── sub/
├── services/       # Ring, background, health and notification services
├── util/
├── widgets/
└── main.dart

docs/
├── privacy_policy.md
└── terms_of_service.md
```

## Getting Started

### Prerequisites

Before running the project, install:

* Flutter SDK
* Dart SDK
* Android Studio / Android SDK
* Xcode for iOS development
* A physical BLE-capable Android or iOS device

A physical device is recommended because BLE smart-ring functionality cannot be fully tested through a standard emulator.

### Install Dependencies

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

Select a connected Android or iOS device when prompted.

## Bluetooth Permissions

The application requires Bluetooth permissions to scan for and communicate with smart rings.

Platform-specific permission configuration is located in:

```text
android/
ios/
```

Depending on the operating system version, nearby-device or location-related permissions may also be required for BLE scanning.

## Local Data

Health and ring measurements are persisted locally using **Drift**, backed by SQLite.

The local storage layer is responsible for:

* health measurements
* historical synchronization
* ring data imports
* locally accumulated metrics
* application state required for monitoring

## Background Synchronization

The project contains services for maintaining ring connectivity and importing health data when possible.

Key services include:

```text
ring_auto_measurement_service
ring_background_import_scheduler
ring_background_keepalive
ring_background_sync
ring_connection_coordinator
ring_measurement_service
ring_sleep_sync_service
```

Background execution behavior depends on operating-system restrictions, especially on iOS and recent Android versions.

## Health Data Notice

Picnique Smart Ring is intended to provide wearable health and wellness information.

Measurements produced by consumer smart-ring hardware may be affected by device placement, sensor quality, movement, firmware, skin contact, and other environmental conditions.

The application should not be treated as a substitute for professional medical diagnosis, treatment, or certified medical equipment.

## Privacy

Privacy-related documentation is available under:

```text
docs/privacy_policy.md
```

## Terms of Service

Service terms are available under:

```text
docs/terms_of_service.md
```

## Third-Party References

Parts of the BLE protocol implementation were informed by publicly available projects and reverse-engineered implementations from the broader smart-ring development community.

Relevant references include:

* `colmi_r06_fbp`
* `colmi_r02_client`
* Gadgetbridge Yawell / Ring implementation
* ATC_RF03_Ring

Individual source licenses should be reviewed before redistribution or commercial release.

See:

```text
lib/ring/README.md
```

for protocol-level implementation notes and attribution details.

## Product

**Picnique Smart Ring**

A wearable companion platform combining smart-ring connectivity, health monitoring, sleep and activity tracking, background synchronization, and rosary-focused wellness experiences.
