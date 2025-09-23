# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

EtoTHSensorMonitor is a SwiftUI-based iOS application that monitors environmental sensor data from ESP32 devices. The app supports dual connectivity methods: Bluetooth Low Energy (BLE) scanning for direct device communication and TCP connections to WiFi-enabled sensor networks.

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -scheme EtoTHSensorMonitor -configuration Debug build

# Build for release
xcodebuild -scheme EtoTHSensorMonitor -configuration Release build

# Run tests
xcodebuild -scheme EtoTHSensorMonitor -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run unit tests only
xcodebuild -scheme EtoTHSensorMonitor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:EtoTHSensorMonitorTests test

# Run UI tests only
xcodebuild -scheme EtoTHSensorMonitor -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:EtoTHSensorMonitorUITests test

# Build and run on device (requires proper code signing)
xcodebuild -scheme EtoTHSensorMonitor -configuration Debug -destination 'generic/platform=iOS' build

# Clean build
xcodebuild -scheme EtoTHSensorMonitor clean
```

### Code Quality and Validation
```bash
# Use SwiftLint if installed (not currently in project but recommended)
swiftlint

# Check for Swift warnings and errors without building
xcodebuild -scheme EtoTHSensorMonitor -destination 'platform=iOS Simulator,name=iPhone 15' -dry-run

# Analyze code for static analysis issues
xcodebuild -scheme EtoTHSensorMonitor -destination 'platform=iOS Simulator,name=iPhone 15' analyze
```

## Architecture Overview

### Core Architecture Pattern
The app follows an MVVM (Model-View-ViewModel) architecture with Combine for reactive programming:

- **Models**: `SensorData` and `TCPSensorData` represent sensor readings from different sources
- **Views**: SwiftUI views in the `Views/` directory handle UI presentation
- **ViewModels**: `SensorViewModel` acts as the primary coordinator between services and views
- **Services**: Abstracted data sources with a composite pattern for dual connectivity

### Dual Connectivity System
The app implements a sophisticated dual connectivity system with automatic priority handling:

1. **CompositeDataService**: Central coordinator that manages both BLE and TCP connections
2. **BluetoothService**: Handles BLE scanning and advertisement parsing
3. **TCPService**: Manages network connections with automatic reconnection
4. **Priority Logic**: TCP connections take precedence over BLE when available

### Data Flow Architecture
```
ESP32 Sensors → [BLE Advertisements | TCP JSON] → Service Layer → CompositeDataService → SensorViewModel → SwiftUI Views
```

Key characteristics:
- **Publisher-Subscriber Pattern**: Uses Combine for reactive data flow
- **Connection Prioritization**: TCP automatically disables BLE scanning when active
- **Data Deduplication**: Prevents duplicate sensor readings from causing excessive UI updates
- **Auto-Reconnection**: TCP service includes exponential backoff retry logic

### Service Layer Details

#### CompositeDataService
- Orchestrates BLE and TCP services with priority management
- Publishes unified data streams regardless of source
- Handles connection state changes and automatic fallback

#### BluetoothService  
- Parses ESP32 "ENV" format advertisements (14-byte payload)
- Supports both manufacturer data and service data locations
- Implements data change detection to prevent duplicate processing

#### TCPService
- Connects to configurable server IP on port 8080
- Handles JSON-formatted sensor data with automatic parsing
- Includes robust error handling and exponential backoff reconnection

### UI Architecture
- **TabView**: Main navigation between Home and History
- **Shared ViewModel**: Single `SensorViewModel` instance across tabs
- **Real-time Indicators**: Data received indicators and connection status
- **Responsive Design**: Supports both iPhone and iPad with landscape optimizations

## Key Components and Files

### Essential Services
- **CompositeDataService.swift**: Central data coordination and connection priority management
- **SensorViewModel.swift**: Primary view model with reactive data binding
- **SettingsManager.swift**: Persistent app configuration and WiFi settings

### Core Models
- **SensorData.swift**: Unified sensor data model with formatting utilities
- **TCPSensorData.swift**: Network-specific model with timestamp validation

### Critical Views
- **ContentView.swift**: App root with lifecycle management and tab navigation
- **HomeView.swift**: Real-time sensor display with connection indicators
- **SettingsView.swift**: Configuration interface including WiFi setup

### Protocol Constants
- **Constants.swift**: ESP32 protocol definitions, parsing offsets, and UI limits

## Development Guidelines

### Working with Sensor Data
- All sensor readings flow through `SensorData` model regardless of source (BLE/TCP)
- Data includes device ID, reading ID, temperature (°C), humidity (%), pressure (hPa), and voltage (V)
- Readings are automatically grouped within 0.5-second windows to prevent UI spam

### Connection Management
- The app prioritizes TCP over BLE automatically
- Connection state is managed reactively through `@Published` properties
- Always check `tcpEnabled` and `isTCPConnected` before making connection decisions

### UI Updates and Animation
- Use `highlightedReadingIds` for temporary visual feedback on new data
- Data received indicators are shown for 1.5 seconds on new readings
- All UI updates must be dispatched to `DispatchQueue.main`

### Adding New Features
When extending the app:

1. **Data Sources**: Add new services to `CompositeDataService` with proper priority handling
2. **UI Components**: Follow the reactive pattern with `@ObservedObject` or `@StateObject`
3. **Settings**: Use `SettingsManager.shared` for persistent configuration
4. **Testing**: Write both unit tests and UI tests for new functionality

### ESP32 Protocol Integration
The app expects ESP32 devices to broadcast "ENV" format advertisements:
- 3-byte header: `0x45, 0x4E, 0x56` ("ENV")
- Device ID (1 byte), Reading ID (2 bytes)
- Temperature (signed 16-bit, deci-celsius), Humidity (unsigned 16-bit, deci-percent)
- Pressure (unsigned 16-bit, deci-hectopascal), Voltage (unsigned 16-bit, centi-volt)

### Network Configuration
TCP connections expect JSON format on port 8080:
```json
{
  "dev_id": 1,
  "timestamp": 1640995200.0,
  "temperature_C": 23.5,
  "humidity_pct": 45.2,  
  "pressure_hPa": 1013.2,
  "voltage_V": 3.45,
  "reading_id": 123
}
```

## Testing Strategy

### Unit Tests (`EtoTHSensorMonitorTests.swift`)
Focus on:
- Data model parsing and formatting
- Service connection logic
- ViewModel state management

### UI Tests (`EtoTHSensorMonitorUITests.swift`)
Focus on:
- Tab navigation
- Settings configuration
- Connection status display
- Data presentation accuracy

### Running Individual Tests
Use `-only-testing:` flag to run specific test classes or methods:
```bash
xcodebuild test -only-testing:EtoTHSensorMonitorTests/TestClassName/testMethodName
```

## Debugging and Troubleshooting

### Common Issues
1. **Bluetooth Permissions**: App requires Location and Bluetooth permissions
2. **TCP Connection**: Verify server IP in Settings and network connectivity
3. **Data Parsing**: Check ESP32 advertisement format matches expected "ENV" protocol
4. **Background Behavior**: iOS may limit BLE scanning in background

### Debug Logging
The app includes extensive console logging with prefixes:
- `🌐` TCP service operations
- `📶` Bluetooth scanning operations  
- `🔄` Connection state changes
- `📱` App lifecycle events

### Performance Considerations
- BLE scanning with duplicates enabled for real-time updates
- Maximum 100 stored readings to prevent memory growth
- Automatic connection management to reduce battery usage

## Platform Requirements

- **iOS**: 14.0+ (due to SwiftUI 2.0 features)
- **Xcode**: 12.0+ for SwiftUI support
- **Device**: iPhone/iPad with Bluetooth LE support
- **Permissions**: Location (for BLE), Network (for TCP)