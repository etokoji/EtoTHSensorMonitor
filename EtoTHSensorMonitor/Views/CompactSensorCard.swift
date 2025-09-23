import SwiftUI

struct CompactSensorCard: View {
    let sensorData: SensorData
    
    var body: some View {
        HStack(spacing: 12) {
            // Device info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("ID: \(sensorData.deviceId)")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let rssi = sensorData.rssi {
                        if rssi < -50 {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "wifi")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Image(systemName: "network")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                if let rssi = sensorData.rssi {
                    Text("\(rssi) dBm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("TCP")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Sensor values (compact)
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 2) {
                    Text(sensorData.formattedTemperature)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                    Text("温度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .center, spacing: 2) {
                    Text(sensorData.formattedHumidity)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("湿度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .center, spacing: 2) {
                    Text(sensorData.formattedPressure)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("気圧")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .center, spacing: 2) {
                    Text(sensorData.formattedVoltage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                    Text("電圧")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        // BLEデバイスの例
        CompactSensorCard(
            sensorData: SensorData(
                deviceAddress: "AA:BB:CC:DD:EE:FF",
                deviceName: "ESP32-Sensor",
                rssi: -45,  // BLEデバイスはRSSIあり
                deviceId: 1,
                readingId: 123,
                temperatureCelsius: 23.5,
                humidityPercent: 65.2,
                pressureHPa: 1013.2,
                voltageVolts: 3.7
            )
        )
        
        // TCPデバイスの例
        CompactSensorCard(
            sensorData: SensorData(
                deviceAddress: "TCP_2",
                deviceName: "TCP Sensor 2",
                rssi: nil,  // TCPデバイスはRSSIなし
                deviceId: 2,
                readingId: 456,
                temperatureCelsius: 25.1,
                humidityPercent: 58.9,
                pressureHPa: 1015.8,
                voltageVolts: 3.6
            )
        )
    }
    .padding()
}
