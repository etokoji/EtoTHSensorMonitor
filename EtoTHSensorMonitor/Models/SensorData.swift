import Foundation

struct SensorData: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let deviceAddress: String
    let deviceName: String?
    let rssi: Int
    let deviceId: UInt8
    let readingId: UInt16
    let temperatureCelsius: Double
    let humidityPercent: Double
    let pressureHPa: Double
    let voltageVolts: Double
    let groupedCount: Int // グループ化された件数
    
    // アニメーション用プロパティ（永続化しない）
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, deviceAddress, deviceName, rssi
        case deviceId, readingId, temperatureCelsius, humidityPercent, pressureHPa, voltageVolts
        case groupedCount
    }
    
    init(timestamp: Date = Date(),
         deviceAddress: String,
         deviceName: String?,
         rssi: Int,
         deviceId: UInt8,
         readingId: UInt16,
         temperatureCelsius: Double,
         humidityPercent: Double,
         pressureHPa: Double,
         voltageVolts: Double,
         groupedCount: Int = 1) {
        self.timestamp = timestamp
        self.deviceAddress = deviceAddress
        self.deviceName = deviceName
        self.rssi = rssi
        self.deviceId = deviceId
        self.readingId = readingId
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = humidityPercent
        self.pressureHPa = pressureHPa
        self.voltageVolts = voltageVolts
        self.groupedCount = groupedCount
    }
    
    var formattedTemperature: String {
        String(format: "%.1f°C", temperatureCelsius)
    }
    
    var formattedHumidity: String {
        String(format: "%.1f%%", humidityPercent)
    }
    
    var formattedPressure: String {
        // すでにhPa単位で保存されているので、直接表示
        return String(format: "%.1f hPa", pressureHPa)
    }
    
    var formattedVoltage: String {
        String(format: "%.2fV", voltageVolts)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current // 現在のタイムゾーンを使用
        return formatter.string(from: timestamp)
    }
}
