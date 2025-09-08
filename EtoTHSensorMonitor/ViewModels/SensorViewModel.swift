import Foundation
import Combine
import CoreBluetooth
import UserNotifications

enum NotificationPriority {
    case normal
    case high
}

class SensorViewModel: ObservableObject {
    @Published var sensorReadings: [SensorData] = []
    @Published var discoveredDevices: [String: SensorData] = [:]
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var selectedDeviceId: UInt8?
    @Published var errorMessage: String?
    
    // ハイライト管理用
    @Published var highlightedReadingIds: Set<UUID> = []
    
    // センサーデータ受信通知用（値が変化した場合のみ）
    let sensorDataSubject = PassthroughSubject<SensorData, Never>()
    
    // 全データ受信通知用（重複含む）
    let dataReceivedSubject = PassthroughSubject<Void, Never>()
    
    private let bluetoothService: BluetoothService
    private var cancellables = Set<AnyCancellable>()
    private var shouldStartScanningWhenReady = false
    
    init(bluetoothService: BluetoothService = BluetoothService()) {
        self.bluetoothService = bluetoothService
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind scanning state
        bluetoothService.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.isScanning = isScanning
            }
            .store(in: &cancellables)
        
        // Bind bluetooth state
        bluetoothService.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                let previousState = self?.bluetoothState
                self?.bluetoothState = state
                
                // Bluetoothが有効になって、スキャンが要求されている場合は自動開始
                if state == .poweredOn && previousState != .poweredOn && self?.shouldStartScanningWhenReady == true {
                    print("📡 Bluetooth is now available, starting scanning automatically")
                    self?.shouldStartScanningWhenReady = false
                    self?.bluetoothService.startScanning()
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
        
        // Bind discovered devices
        bluetoothService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
            }
            .store(in: &cancellables)
        
        // Listen for new sensor data (value changes only)
        bluetoothService.sensorDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.sensorDataSubject.send(sensorData)
            }
            .store(in: &cancellables)
        
        // Listen for all data received (including duplicates) for history
        bluetoothService.dataReceivedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dataReceivedSubject.send()
            }
            .store(in: &cancellables)
        
        // Listen for all data (including duplicates) to add to reading history
        bluetoothService.allDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.addSensorReading(sensorData)
                // バックグラウンド用に最新データを保存
                self?.saveLatestDataForBackground(sensorData)
            }
            .store(in: &cancellables)
    }
    
    private func addSensorReading(_ reading: SensorData) {
        // Filter by selected device if set
        if let selectedId = selectedDeviceId, reading.deviceId != selectedId {
            return
        }
        
        // 0.5秒以内の近接データをグループ化（最初のエントリーをチェック）
        if let firstReading = sensorReadings.first,
           firstReading.deviceAddress == reading.deviceAddress,
           reading.timestamp.timeIntervalSince(firstReading.timestamp) <= 0.5 {
            // 近接データの場合、最初のアイテムの件数を更新
            let updatedReading = SensorData(
                timestamp: firstReading.timestamp, // 最初の受信時刻を保持
                deviceAddress: firstReading.deviceAddress,
                deviceName: firstReading.deviceName,
                rssi: firstReading.rssi,
                deviceId: firstReading.deviceId,
                readingId: firstReading.readingId,
                temperatureCelsius: firstReading.temperatureCelsius,
                humidityPercent: firstReading.humidityPercent,
                pressureHPa: firstReading.pressureHPa,
                voltageVolts: firstReading.voltageVolts,
                groupedCount: firstReading.groupedCount + 1,
                isFromBackground: firstReading.isFromBackground // バックグラウンドフラグを継承
            )
            
            // ハイライト用（グループ化された場合も同じIDを使用）
            highlightedReadingIds.remove(firstReading.id)
            sensorReadings[0] = updatedReading
            highlightedReadingIds.insert(updatedReading.id)
            
            // 3秒後にハイライトを除去
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.highlightedReadingIds.remove(updatedReading.id)
            }
        } else {
            // 新しいグループとして先頭に追加
            sensorReadings.insert(reading, at: 0)
            
            // ハイライトアニメーションを開始
            highlightedReadingIds.insert(reading.id)
            
            // 3秒後にハイライトを除去
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.highlightedReadingIds.remove(reading.id)
            }
        }
        
        // Limit the number of stored readings
        if sensorReadings.count > Constants.maxStoredReadings {
            let removedReading = sensorReadings.removeLast()
            // 削除されたアイテムのハイライトもクリア
            highlightedReadingIds.remove(removedReading.id)
        }
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard bluetoothState == .poweredOn else {
            // Bluetoothがまだ準備できていない場合は、準備でき次第自動開始するようフラグを設定
            if bluetoothState == .unknown || bluetoothState == .resetting {
                print("⚠️ Bluetooth not ready yet, will start scanning when available")
                shouldStartScanningWhenReady = true
            }
            errorMessage = getBluetoothErrorMessage()
            return
        }
        
        print("📶 Starting Bluetooth scanning immediately")
        bluetoothService.startScanning()
        errorMessage = nil
        shouldStartScanningWhenReady = false
    }
    
    func stopScanning() {
        bluetoothService.stopScanning()
    }
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func clearReadings() {
        sensorReadings.removeAll()
        highlightedReadingIds.removeAll()
    }
    
    func filterByDevice(_ deviceId: UInt8?) {
        selectedDeviceId = deviceId
        
        // If filtering, rebuild the list from discovered devices
        if let deviceId = deviceId {
            sensorReadings = sensorReadings.filter { $0.deviceId == deviceId }
        }
    }
    
    private func getBluetoothErrorMessage() -> String {
        switch bluetoothState {
        case .poweredOff:
            return "Bluetoothがオフになっています。設定でBluetoothをオンにしてください。"
        case .unauthorized:
            return "Bluetoothへのアクセスが許可されていません。設定でアクセスを許可してください。"
        case .unsupported:
            return "このデバイスはBluetoothをサポートしていません。"
        case .unknown, .resetting:
            return "Bluetoothの状態を確認中です...しばらくお待ちください。"
        default:
            return "Bluetoothに問題があります。"
        }
    }
    
    private func saveLatestDataForBackground(_ sensorData: SensorData) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sensorData)
            UserDefaults.standard.set(data, forKey: "latestSensorData")
            UserDefaults.standard.set(Date(), forKey: "latestSensorDataTimestamp")
            // Debug用のログは削除（スパム防止）
            
            // 電池残量チェックと通知
            checkBatteryLevelAndNotify(sensorData)
        } catch {
            print("❌ Failed to save background data: \(error)")
        }
    }
    
    private func checkBatteryLevelAndNotify(_ sensorData: SensorData) {
        let settings = SettingsManager.shared
        
        // 通知が無効な場合は何もしない
        guard settings.batteryNotificationsEnabled else { return }
        
        let batteryStatus = settings.getBatteryStatus(voltage: sensorData.voltageVolts)
        let deviceName = sensorData.deviceName ?? "ESP32センサー"
        
        switch batteryStatus {
        case .critical:
            scheduleBatteryNotification(
                title: "🔋 電池交換必要！",
                message: "\(deviceName)の電池が残りわずかです (\(String(format: "%.2f", sensorData.voltageVolts))V)",
                identifier: "battery_critical_\(sensorData.deviceId)",
                priority: .high
            )
            
        case .low:
            // 前回通知から一定時間経過している場合のみ通知
            let lastNotificationKey = "last_battery_low_\(sensorData.deviceId)"
            let lastNotification = UserDefaults.standard.object(forKey: lastNotificationKey) as? Date ?? Date.distantPast
            
            if Date().timeIntervalSince(lastNotification) > settings.notificationCooldownPeriod {
                scheduleBatteryNotification(
                    title: "⚠️ 電池残量低下",
                    message: "\(deviceName)の電池残量が少なくなっています (\(String(format: "%.2f", sensorData.voltageVolts))V)",
                    identifier: "battery_low_\(sensorData.deviceId)",
                    priority: .normal
                )
                UserDefaults.standard.set(Date(), forKey: lastNotificationKey)
            }
            
        case .normal:
            // 正常な場合は通知しない
            break
        }
    }
    
    private func scheduleBatteryNotification(title: String, message: String, identifier: String, priority: NotificationPriority) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = priority == .high ? .defaultCritical : .default
        content.categoryIdentifier = "BATTERY_ALERT"
        
        // 重要度に応じて遅延を調整
        let delay = priority == .high ? 0.5 : 1.0
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule battery notification: \(error)")
            } else {
                print("🔋 Battery notification scheduled: \(title)")
            }
        }
    }
    
    // MARK: - Background Data Integration
    
    func loadAndIntegrateBackgroundData() {
        guard let backgroundData = BackgroundTaskManager.shared.loadLatestSensorData() else {
            print("🌙 No background data available")
            return
        }
        
        // 既存データと比較して新しい場合のみ統合
        let isNewer = sensorReadings.isEmpty || 
                     sensorReadings.first?.timestamp ?? Date.distantPast < backgroundData.timestamp
        
        if isNewer {
            // バックグラウンドフラグを付けて新しいSensorDataを作成
            let backgroundSensorData = SensorData(
                timestamp: backgroundData.timestamp,
                deviceAddress: backgroundData.deviceAddress,
                deviceName: backgroundData.deviceName,
                rssi: backgroundData.rssi,
                deviceId: backgroundData.deviceId,
                readingId: backgroundData.readingId,
                temperatureCelsius: backgroundData.temperatureCelsius,
                humidityPercent: backgroundData.humidityPercent,
                pressureHPa: backgroundData.pressureHPa,
                voltageVolts: backgroundData.voltageVolts,
                groupedCount: 1,
                isFromBackground: true
            )
            
            print("🌙 Integrating background data: \(backgroundData.formattedTimestamp)")
            
            // 先頭に追加してハイライト
            sensorReadings.insert(backgroundSensorData, at: 0)
            highlightedReadingIds.insert(backgroundSensorData.id)
            
            // 5秒後にハイライト解除（バックグラウンドデータは少し長めに）
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.highlightedReadingIds.remove(backgroundSensorData.id)
            }
            
            // リストサイズを制限
            if sensorReadings.count > Constants.maxStoredReadings {
                let removedReading = sensorReadings.removeLast()
                highlightedReadingIds.remove(removedReading.id)
            }
            
            // UI更新をトリガー
            objectWillChange.send()
        } else {
            print("🌙 Background data is older than current data, skipping integration")
        }
    }
    
    // MARK: - Computed Properties
    
    var uniqueDeviceIds: [UInt8] {
        let deviceIds = Set(sensorReadings.map { $0.deviceId })
        return Array(deviceIds).sorted()
    }
    
    var latestReadingsByDevice: [UInt8: SensorData] {
        var latestReadings: [UInt8: SensorData] = [:]
        
        for reading in sensorReadings {
            if let existing = latestReadings[reading.deviceId] {
                if reading.timestamp > existing.timestamp {
                    latestReadings[reading.deviceId] = reading
                }
            } else {
                latestReadings[reading.deviceId] = reading
            }
        }
        
        return latestReadings
    }
    
    var hasReadings: Bool {
        !discoveredDevices.isEmpty
    }
    
    var bluetoothStateDescription: String {
        switch bluetoothState {
        case .poweredOn:
            return "接続可能"
        case .poweredOff:
            return "オフ"
        case .unauthorized:
            return "未許可"
        case .unsupported:
            return "非サポート"
        case .resetting:
            return "リセット中"
        default:
            return "不明"
        }
    }
}
