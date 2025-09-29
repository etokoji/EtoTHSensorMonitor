import Foundation
import UIKit
import CoreBluetooth
import Combine

class BluetoothService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var discoveredDevices: [String: SensorData] = [:]
    @Published var bluetoothState: CBManagerState = .unknown
    
    private var centralManager: CBCentralManager!
    private var lastSensorData: [String: (temperature: Double, humidity: Double, pressure: Double, voltage: Double)] = [:]
    
    let sensorDataPublisher = PassthroughSubject<SensorData, Never>()
    let dataReceivedPublisher = PassthroughSubject<Void, Never>()
    let allDataPublisher = PassthroughSubject<SensorData, Never>()
    
    private var bluetoothStateString: String {
        switch centralManager.state {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "Unknown State"
        }
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        print("📱 iPad/iOS Bluetooth Debug - Starting scan...")
        print("📱 Device: \(UIDevice.current.model)")
        print("📱 iOS Version: \(UIDevice.current.systemVersion)")
        print("📱 BT State: \(centralManager.state.rawValue) (\(bluetoothStateString))")
        
        guard centralManager.state == .poweredOn else {
            print("⚠️ Bluetooth is not powered on - State: \(bluetoothStateString)")
            return
        }
        
        isScanning = true
        
        // iPad対応: より積極的なスキャンオプションを使用
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
            CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [] // iPadでより多くのデバイスを検出
        ]
        
        centralManager.scanForPeripherals(withServices: nil, options: scanOptions)
        print("✅ Started scanning for peripherals with enhanced iPad options")
        
        // iPad用デバッグ: 10秒後にスキャン状態をチェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isScanning {
                print("📝 10s scan check - Found devices: \(self.discoveredDevices.count)")
                print("📝 BT State: \(self.centralManager.state.rawValue)")
                print("📝 Is Scanning: \(self.centralManager.isScanning)")
            }
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        print("Stopped scanning")
    }
    
    private func decodeENVPayload(from data: Data) -> (deviceId: UInt8, readingId: UInt16, temperature: Double, humidity: Double, pressure: Double, voltage: Double)? {
        // Check minimum length
        guard data.count >= Constants.minPayloadLength else { return nil }
        
        var offset = 0
        
        // Check for ENV header at start or after 2-byte company ID
        if data.prefix(Constants.headerLength) == Constants.envHeader {
            offset = 0
        } else if data.count >= Constants.payloadWithCompanyIdLength &&
                  data.subdata(in: 2..<(2 + Constants.headerLength)) == Constants.envHeader {
            offset = 2
        } else {
            return nil
        }
        
        // Ensure we have enough data after finding the header
        guard data.count >= offset + Constants.minPayloadLength else { return nil }
        
        // Parse data (big-endian format)
        // b'ENV' + dev_id(u1) + r_id(u2) + temp(dC i2) + hum(d% u2) + pres(dhPa u2) + vdd(cV u2)
        let deviceId = data[offset + Constants.deviceIdOffset]
        
        let readingId = UInt16(data[offset + Constants.readingIdOffset]) << 8 |
                       UInt16(data[offset + Constants.readingIdOffset + 1])
        
        // Temperature is signed 16-bit (deci-celsius)
        let tempRaw = Int16(data[offset + Constants.temperatureOffset]) << 8 |
                     Int16(data[offset + Constants.temperatureOffset + 1])
        let temperature = Double(tempRaw) / Constants.temperatureScale
        
        // Humidity is unsigned 16-bit (deci-percent)
        let humidityRaw = UInt16(data[offset + Constants.humidityOffset]) << 8 |
                         UInt16(data[offset + Constants.humidityOffset + 1])
        let humidity = Double(humidityRaw) / Constants.humidityScale
        
        // Pressure is unsigned 16-bit (deci-hectopascal = 0.1 hPa)
        let pressureRaw = UInt16(data[offset + Constants.pressureOffset]) << 8 |
                         UInt16(data[offset + Constants.pressureOffset + 1])
        let pressure = Double(pressureRaw) / Constants.pressureScale  // Convert to hPa
        
        // Voltage is unsigned 16-bit (centi-volt)
        let voltageRaw = UInt16(data[offset + Constants.voltageOffset]) << 8 |
                        UInt16(data[offset + Constants.voltageOffset + 1])
        let voltage = Double(voltageRaw) / Constants.voltageScale
        
        return (deviceId, readingId, temperature, humidity, pressure, voltage)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            stopScanning()
        case .unauthorized:
            print("Bluetooth access denied")
        case .unsupported:
            print("Bluetooth not supported")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let deviceModel = UIDevice.current.model
        let peripheralName = peripheral.name ?? ""
        let advertisementLocalName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        
        // Check manufacturer data first
        var payloads: [Data] = []
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            payloads.append(manufacturerData)
        }
        
        // Check service data if no manufacturer data
        if payloads.isEmpty, let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            payloads.append(contentsOf: serviceData.values)
        }
        
        // デバイス名の違いをデバッグするためのログ出力
        if !peripheralName.isEmpty || advertisementLocalName != nil {
            print("[センサー] BLEデバイス発見 (\(deviceModel)):")
            print("  - peripheral.name: '\(peripheralName)'")
            print("  - advertisementData localName: '\(advertisementLocalName ?? "nil")'")
            print("  - peripheral.identifier: \(peripheral.identifier)")
            print("  - RSSI: \(RSSI.intValue)")
        }
        
        for payload in payloads {
            guard let decoded = decodeENVPayload(from: payload) else { continue }
            
            let deviceAddress = peripheral.identifier.uuidString
            let deviceName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            
            // Check if sensor data has changed
            let isDuplicate = if let lastData = lastSensorData[deviceAddress] {
                abs(lastData.temperature - decoded.temperature) < 0.01 &&
                abs(lastData.humidity - decoded.humidity) < 0.01 &&
                abs(lastData.pressure - decoded.pressure) < 0.01 &&
                abs(lastData.voltage - decoded.voltage) < 0.001
            } else {
                false
            }
            
            lastSensorData[deviceAddress] = (decoded.temperature, decoded.humidity, decoded.pressure, decoded.voltage)
            
            let sensorData = SensorData(
                deviceAddress: deviceAddress,
                deviceName: deviceName,
                rssi: RSSI.intValue,  // BLE接続なので実際のRSSI値を使用
                deviceId: decoded.deviceId,
                readingId: decoded.readingId,
                temperatureCelsius: decoded.temperature,
                humidityPercent: decoded.humidity,
                pressureHPa: decoded.pressure,
                voltageVolts: decoded.voltage
            )
            
            DispatchQueue.main.async {
                // 常に最新のタイムスタンプで更新
                self.discoveredDevices[deviceAddress] = sensorData
                
                // 全データ受信を通知（重複も含む）
                self.dataReceivedPublisher.send()
                
                // すべてのデータ（重複含む）を履歴用に通知
                self.allDataPublisher.send(sensorData)
                
                // 重複でない場合のみアニメーション付きで通知
                if !isDuplicate {
                    self.sensorDataPublisher.send(sensorData)
                }
            }
            
            print("📃 Device: \(decoded.deviceId), Reading: \(decoded.readingId), Temp: \(decoded.temperature)°C, Humidity: \(decoded.humidity)%, Pressure: \(decoded.pressure)hPa, Voltage: \(decoded.voltage)V, RSSI: \(RSSI)")
        }
    }
}
