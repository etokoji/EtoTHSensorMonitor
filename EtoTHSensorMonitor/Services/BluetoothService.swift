import Foundation
import CoreBluetooth
import Combine

class BluetoothService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var discoveredDevices: [String: SensorData] = [:]
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isInBackground = false
    
    private var centralManager: CBCentralManager!
    private var lastSensorData: [String: (temperature: Double, humidity: Double, pressure: Double, voltage: Double, illuminance: Double?)] = [:]
    private var wasScanningBeforeBackground = false
    
    /// バックグラウンド状態復元用の識別子
    static let restoreIdentifier = "com.etokoji.EtoTHSensorMonitor.bluetooth"
    
    let sensorDataPublisher = PassthroughSubject<SensorData, Never>()
    let dataReceivedPublisher = PassthroughSubject<Void, Never>()
    let allDataPublisher = PassthroughSubject<SensorData, Never>()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BluetoothService.restoreIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on")
            return
        }
        
        isScanning = true
        centralManager.scanForPeripherals(withServices: [Constants.envServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        print("📶 Started scanning for peripherals (background: \(isInBackground))")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        print("📶 Stopped scanning")
    }
    
    /// バックグラウンド移行時の処理
    func handleEnterBackground() {
        isInBackground = true
        wasScanningBeforeBackground = isScanning
        
        if isScanning {
            // バックグラウンドでもスキャンを継続（bluetooth-centralモードにより可能）
            // ただしiOSがallowDuplicatesを無視するため、重複フィルタリングがONになる
            print("📶 Entering background - BLE scanning will continue with reduced frequency")
        }
    }
    
    /// フォアグラウンド復帰時の処理
    func handleEnterForeground() {
        isInBackground = false
        
        if wasScanningBeforeBackground && !isScanning {
            // バックグラウンドでスキャンが停止されていた場合、再開
            print("📶 Returning to foreground - restarting BLE scan")
            startScanning()
        } else if isScanning {
            // スキャン中の場合、フォアグラウンド向けに再開（allowDuplicates有効化のため）
            print("📶 Returning to foreground - refreshing BLE scan for full-speed")
            centralManager.stopScan()
            centralManager.scanForPeripherals(withServices: [Constants.envServiceUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        }
    }
    
    private func decodeENVPayload(from data: Data) -> (deviceId: UInt8, readingId: UInt16, temperature: Double, humidity: Double, pressure: Double, voltage: Double, illuminance: Double?)? {
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
        // 旧: b'ENV' + dev_id(u1) + r_id(u2) + temp(dC i2) + hum(d% u2) + pres(dhPa u2) + vdd(cV u2)
        // 新: 末尾に lux(dlx u2) を追加（0.1 lx 単位）
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

        // Illuminance is optional unsigned 16-bit (1 lx)
        var illuminance: Double? = nil
        if data.count >= offset + Constants.payloadWithIlluminanceLength {
            let luxRaw = UInt16(data[offset + Constants.illuminanceOffset]) << 8 |
                        UInt16(data[offset + Constants.illuminanceOffset + 1])
            illuminance = Double(luxRaw) / Constants.illuminanceScale
        }
        
        return (deviceId, readingId, temperature, humidity, pressure, voltage, illuminance)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        switch central.state {
        case .poweredOn:
            print("📶 Bluetooth is powered on")
            // 状態復元後にスキャンが必要な場合、自動再開
            if wasScanningBeforeBackground && !isScanning {
                print("📶 Resuming scanning after state restoration")
                startScanning()
            }
        case .poweredOff:
            print("📶 Bluetooth is powered off")
            stopScanning()
        case .unauthorized:
            print("📶 Bluetooth access denied")
        case .unsupported:
            print("📶 Bluetooth not supported")
        default:
            print("📶 Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    /// CoreBluetooth状態復元デリゲート - アプリがシステムに終了された後に再起動された場合に呼ばれる
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        print("📶 CoreBluetooth state restoration")
        
        // 復元前にスキャン中だったかどうかを確認
        if let restoredScanServices = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            print("📶 Restored scan services: \(restoredScanServices)")
            wasScanningBeforeBackground = true
        } else if dict[CBCentralManagerRestoredStateScanOptionsKey] != nil {
            print("📶 Restored scan options found - was scanning")
            wasScanningBeforeBackground = true
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Check manufacturer data first
        var payloads: [Data] = []
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            payloads.append(manufacturerData)
        }
        
        // Check service data if no manufacturer data
        if payloads.isEmpty, let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            payloads.append(contentsOf: serviceData.values)
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
                abs(lastData.voltage - decoded.voltage) < 0.001 &&
                (lastData.illuminance == nil && decoded.illuminance == nil ||
                 abs((lastData.illuminance ?? 0.0) - (decoded.illuminance ?? 0.0)) < 0.01)
            } else {
                false
            }
            
            lastSensorData[deviceAddress] = (decoded.temperature, decoded.humidity, decoded.pressure, decoded.voltage, decoded.illuminance)
            
            let sensorData = SensorData(
                deviceAddress: deviceAddress,
                deviceName: deviceName,
                rssi: RSSI.intValue,  // BLE接続なので実際のRSSI値を使用
                deviceId: decoded.deviceId,
                readingId: decoded.readingId,
                temperatureCelsius: decoded.temperature,
                humidityPercent: decoded.humidity,
                pressureHPa: decoded.pressure,
                voltageVolts: decoded.voltage,
                illuminanceLux: decoded.illuminance
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
            
            if let lux = decoded.illuminance {
                print("📃 Device: \(decoded.deviceId), Reading: \(decoded.readingId), Temp: \(decoded.temperature)°C, Humidity: \(decoded.humidity)%, Pressure: \(decoded.pressure)hPa, Voltage: \(decoded.voltage)V, Lux: \(lux)lx, RSSI: \(RSSI)")
            } else {
                print("📃 Device: \(decoded.deviceId), Reading: \(decoded.readingId), Temp: \(decoded.temperature)°C, Humidity: \(decoded.humidity)%, Pressure: \(decoded.pressure)hPa, Voltage: \(decoded.voltage)V, RSSI: \(RSSI)")
            }
        }
    }
}
