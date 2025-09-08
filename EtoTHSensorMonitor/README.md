# EtoTHSensorMonitor

EtoTHSensorMonitor is a SwiftUI application designed to monitor sensor data such as temperature and humidity. The application connects to Bluetooth-enabled sensors and displays real-time readings to the user.

## Project Structure

- **EtoTHSensorMonitorApp.swift**: Main entry point of the application.
- **ContentView.swift**: Contains the main user interface.
- **Models/SensorData.swift**: Defines the data structure for sensor readings.
- **Views/SensorReadingView.swift**: Displays current sensor readings.
- **ViewModels/SensorViewModel.swift**: Manages data for the sensor readings view.
- **Services/BluetoothService.swift**: Handles Bluetooth communication.
- **Utils/Constants.swift**: Contains constant values used throughout the application.
- **Info.plist**: Configuration settings for the application.

## Setup Instructions

1. Clone the repository.
2. Open the project in Xcode.
3. Connect your Bluetooth sensor device.
4. Run the application on a compatible device or simulator.

## License

This project is licensed under the MIT License.