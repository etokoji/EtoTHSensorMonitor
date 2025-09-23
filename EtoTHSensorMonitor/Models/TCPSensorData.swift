import Foundation

struct TCPSensorData: Codable {
    let dev_id: UInt8
    let pressure_hPa: Double  // hPa単位の値（ESP32側で修正済み）
    let timestamp: TimeInterval  // Unix timestamp in seconds
    let humidity_pct: Double
    let reading_id: UInt16
    let voltage_V: Double
    let temperature_C: Double
    
    // Convert TCP sensor data to unified SensorData
    func toSensorData(deviceAddress: String = "TCP", deviceName: String? = nil, rssi: Int? = nil) -> SensorData {
        // Check if timestamp seems reasonable (should be after 2020)
        let minimumValidTimestamp: TimeInterval = 1577836800 // January 1, 2020
        let currentTime = Date().timeIntervalSince1970
        
        let adjustedTimestamp: TimeInterval
        let date: Date
        
        if timestamp < minimumValidTimestamp {
            // Timestamp seems invalid, use current time instead
            adjustedTimestamp = currentTime
            date = Date() // Current time
            print("⚠️ Invalid timestamp \(timestamp) detected, using current time instead")
        } else {
            // Timestamp seems valid
            adjustedTimestamp = timestamp
            date = Date(timeIntervalSince1970: timestamp)
        }
        
        // デバッグ用: タイムスタンプ変換のログ
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        print("🕰️ Timestamp conversion: \(timestamp) -> \(formatter.string(from: date)) (adjusted: \(adjustedTimestamp != timestamp ? "YES" : "NO"))")
        
        // ESP32側で既にhPa単位に変換済みなので、そのまま使用
        let pressureHPa = pressure_hPa
        
        return SensorData(
            timestamp: date,
            deviceAddress: deviceAddress,
            deviceName: deviceName ?? "TCP Server",
            rssi: rssi,
            deviceId: dev_id,
            readingId: reading_id,
            temperatureCelsius: temperature_C,
            humidityPercent: humidity_pct,
            pressureHPa: pressureHPa,
            voltageVolts: voltage_V
        )
    }
}
