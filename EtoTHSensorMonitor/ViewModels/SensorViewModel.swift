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
    @Published var selectedDeviceId: UInt8? = nil
    @Published var errorMessage: String?
    @Published var showBluetoothUnauthorizedAlert = false
    
    // 過去ログ関連
    @Published var availableLogDates: [Date] = []
    @Published var selectedDateReadings: [SensorData] = []
    @Published var isLoadingDate: Bool = false
    @Published var loadedDate: Date? = nil
    
    // ハイライト管理用
    @Published var highlightedReadingIds: Set<UUID> = []
    @Published var showDataReceivedIndicator = false
    // センサーデータ受信通知用（値が変化した場合のみ）
    let sensorDataSubject = PassthroughSubject<SensorData, Never>()
    
    // 全データ受信通知用（重複含む）
    let dataReceivedSubject = PassthroughSubject<Void, Never>()
    
    let dataService: CompositeDataService
    private var cancellables = Set<AnyCancellable>()
    private var shouldStartScanningWhenReady = false
    
    init(dataService: CompositeDataService = CompositeDataService()) {
        self.dataService = dataService
        setupBindings()
        loadAvailableDates()
    }
    
    private func setupBindings() {
        // ログファイルが新規作成されたら日付リストを更新
        NotificationCenter.default.publisher(for: ReadingLogManager.didCreateNewLogFileNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadAvailableDates()
            }
            .store(in: &cancellables)

        // Bind scanning state
        dataService.$isBluetoothScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.isScanning = isScanning
            }
            .store(in: &cancellables)
        
        // Bind bluetooth state
        dataService.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                let previousState = self?.bluetoothState
                self?.bluetoothState = state
                
                // Bluetooth未許可になった場合はアラートを表示
                if state == .unauthorized && previousState != .unauthorized {
                    self?.showBluetoothUnauthorizedAlert = true
                }
                
                // Bluetoothが有効になって、スキャンが要求されている場合は自動開始
                if state == .poweredOn && previousState != .poweredOn && self?.shouldStartScanningWhenReady == true {
                    print("📡 Bluetooth is now available, starting scanning automatically")
                    self?.shouldStartScanningWhenReady = false
                    self?.dataService.startBluetoothScanning()
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
        
        // Bind discovered devices
        dataService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
            }
            .store(in: &cancellables)
        
        // Listen for new sensor data (value changes only)
        dataService.sensorDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.sensorDataSubject.send(sensorData)
            }
            .store(in: &cancellables)
        
        // Listen for all data received (including duplicates) for history
        dataService.dataReceivedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dataReceivedSubject.send()
            }
            .store(in: &cancellables)
        
        // Listen for all data (including duplicates) to add to reading history
        dataService.allDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.addSensorReading(sensorData)
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
                rssi: firstReading.rssi,  // BLEまTCPの判定はdeviceAddressで判定
                deviceId: firstReading.deviceId,
                readingId: firstReading.readingId,
                temperatureCelsius: firstReading.temperatureCelsius,
                humidityPercent: firstReading.humidityPercent,
                pressureHPa: firstReading.pressureHPa,
                voltageVolts: firstReading.voltageVolts,
                illuminanceLux: firstReading.illuminanceLux,
                groupedCount: firstReading.groupedCount + 1
            )
            
            // ハイライト用（グループ化された場合も同じIDを使用）
            highlightedReadingIds.remove(firstReading.id)
            sensorReadings[0] = updatedReading
            highlightedReadingIds.insert(updatedReading.id)
            
            // 受信インジケーターを表示（グループ化時も）
            showDataReceivedIndicator = true
            
            // 1.5秒後にインジケーターを非表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showDataReceivedIndicator = false
            }
            
            // 3秒後にハイライトを除去
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.highlightedReadingIds.remove(updatedReading.id)
            }
        } else {
            // 新しいグループとして先頭に追加
            sensorReadings.insert(reading, at: 0)
            
            // ハイライトアニメーションを開始
            highlightedReadingIds.insert(reading.id)
            
            // 受信インジケーターを表示
            showDataReceivedIndicator = true
            
            // 1.5秒後にインジケーターを非表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showDataReceivedIndicator = false
            }
            
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
        
        // ファイルにデータを保存
        ReadingLogManager.shared.append(reading)
        
        // Widget用共有コンテナに書き込む
        SharedDataManager.shared.writeLatestReading(reading)
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
        dataService.startBluetoothScanning()
        errorMessage = nil
        shouldStartScanningWhenReady = false
    }
    
    func stopScanning() {
        dataService.stopBluetoothScanning()
    }
    
    func toggleScanning() {
        dataService.toggleBluetoothScanning()
    }
    
    func clearReadings() {
        sensorReadings.removeAll()
        highlightedReadingIds.removeAll()
    }
    
    /// 利用可能なログ日付一覧を非同期で取得
    func loadAvailableDates() {
        DispatchQueue.global(qos: .background).async {
            let dates = ReadingLogManager.shared.availableLogDates()
            DispatchQueue.main.async {
                self.availableLogDates = dates
                print("📝 Found \(dates.count) log files")
            }
        }
    }

    /// 指定した日付のログを非同期で読み込む
    func loadReadings(for date: Date) {
        isLoadingDate = true
        loadedDate = date
        selectedDateReadings = []
        DispatchQueue.global(qos: .background).async {
            let readings = ReadingLogManager.shared.loadDayReadings(for: date)
            DispatchQueue.main.async {
                self.selectedDateReadings = readings
                self.isLoadingDate = false
                print("📝 Loaded \(readings.count) readings for \(date)")
            }
        }
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
        return dataService.hasReadings
    }
    
    var bluetoothStateDescription: String {
        return dataService.bluetoothStateDescription
    }
    
    var connectionStatusText: String {
        return dataService.connectionStatusText
    }
    
    var detailedConnectionStatus: String {
        return dataService.detailedConnectionStatus
    }
    
    var activeConnectionType: String {
        return isScanning ? "Bluetooth" : "None"
    }
}
