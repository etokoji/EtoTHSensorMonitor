import Foundation
import CoreBluetooth

struct Constants {
    // ESP32 ENV payload constants
    static let envHeader = Data([0x45, 0x4E, 0x56]) // "ENV" in bytes
    // 旧フォーマット(照度なし): 3 + 1 + 2 + 2 + 2 + 2 + 2 = 14 bytes
    // 新フォーマット(照度あり): 3 + 1 + 2 + 2 + 2 + 2 + 2 + 2 = 16 bytes
    static let minPayloadLength = 14
    static let payloadWithCompanyIdLength = 16
    static let payloadWithIlluminanceLength = 16
    
    // Data parsing offsets (new format with pressure)
    static let headerLength = 3
    static let deviceIdOffset = 3
    static let readingIdOffset = 4
    static let temperatureOffset = 6  // temp(dC i2) - signed 16-bit
    static let humidityOffset = 8     // hum(d% u2) - unsigned 16-bit
    static let pressureOffset = 10    // pres(Pa u2) - unsigned 16-bit
    static let voltageOffset = 12     // vdd(cV u2) - unsigned 16-bit
    static let illuminanceOffset = 14 // lux(0.1 lx u2) - unsigned 16-bit (optional)
    
    // Unit conversion factors
    static let temperatureScale = 10.0  // 0.1°C units (deci-celsius)
    static let humidityScale = 10.0     // 0.1% units (deci-percent)
    static let pressureScale = 10.0     // 0.1 hPa units (deci-hectopascal)
    static let voltageScale = 100.0     // 0.01V units (centi-volt)
    static let illuminanceScale = 1.0   // 1 lx units
    
    // Bluetooth scanning
    static let scanTimeout: TimeInterval = 0.3
    static let scanInterval: TimeInterval = 0.1
    /// ESP32が送信するService UUID（バックグラウンドスキャン用）
    static let envServiceUUID = CBUUID(string: "FFAB")
    
    // UI Constants
    static let maxStoredReadings = 100
    static let rssiGoodThreshold = -60
    static let rssiFairThreshold = -80
}
