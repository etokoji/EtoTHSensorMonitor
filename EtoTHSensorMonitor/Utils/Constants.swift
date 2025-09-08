import Foundation

struct Constants {
    // ESP32 ENV payload constants
    static let envHeader = Data([0x45, 0x4E, 0x56]) // "ENV" in bytes
    static let minPayloadLength = 14  // 3 + 1 + 2 + 2 + 2 + 2 + 2 = 14 bytes
    static let payloadWithCompanyIdLength = 16
    
    // Data parsing offsets (new format with pressure)
    static let headerLength = 3
    static let deviceIdOffset = 3
    static let readingIdOffset = 4
    static let temperatureOffset = 6  // temp(dC i2) - signed 16-bit
    static let humidityOffset = 8     // hum(d% u2) - unsigned 16-bit
    static let pressureOffset = 10    // pres(Pa u2) - unsigned 16-bit
    static let voltageOffset = 12     // vdd(cV u2) - unsigned 16-bit
    
    // Unit conversion factors
    static let temperatureScale = 10.0  // 0.1°C units (deci-celsius)
    static let humidityScale = 10.0     // 0.1% units (deci-percent)
    static let pressureScale = 10.0     // 0.1 hPa units (deci-hectopascal)
    static let voltageScale = 100.0     // 0.01V units (centi-volt)
    
    // Bluetooth scanning
    static let scanTimeout: TimeInterval = 0.3
    static let scanInterval: TimeInterval = 0.1
    
    // UI Constants
    static let maxStoredReadings = 100
    static let rssiGoodThreshold = -60
    static let rssiFairThreshold = -80
}
