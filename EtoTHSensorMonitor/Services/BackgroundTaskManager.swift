import Foundation
import BackgroundTasks
import UIKit
import UserNotifications
import Combine

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let backgroundTaskIdentifier = "com.etokoji.EtoTHSensorMonitor.sensorScan"
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    func registerBackgroundTask() {
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSensorScan(task: task as! BGProcessingTask)
        }
        
        if success {
            print("✅ Background task registration successful")
        } else {
            print("❌ Background task registration failed - task may already be registered")
        }
        
        // シミュレーターでの制限を警告
        #if targetEnvironment(simulator)
        print("⚠️ Running in iOS Simulator - background tasks have limited functionality")
        #endif
    }
    
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            // 既存のタスクをキャンセルしてから新しいタスクをスケジュール
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
            try BGTaskScheduler.shared.submit(request)
            print("📱 Background task scheduled successfully")
        } catch let error as NSError {
            let errorMessage = getBackgroundTaskErrorMessage(error)
            print("❌ Failed to schedule background task: \(errorMessage)")
            
            // シミュレーターでは無視する（エラーでも続行）
            #if targetEnvironment(simulator)
            print("📱 Running in simulator - background tasks are limited")
            #endif
        }
    }
    
    private func handleBackgroundSensorScan(task: BGProcessingTask) {
        print("🔄 Starting background sensor scan")
        
        // Schedule the next background task
        scheduleBackgroundTask()
        
        // Create a Bluetooth service for background scanning
        let bluetoothService = BluetoothService()
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            bluetoothService.stopScanning()
            task.setTaskCompleted(success: false)
        }
        
        // Start a brief scan
        DispatchQueue.global(qos: .background).async {
            bluetoothService.startScanning()
            
            var dataReceived = false
            var timer: DispatchWorkItem?
            
            // データ受信時の早期終了処理
            let dataReceivedCancellable = bluetoothService.sensorDataPublisher.sink { _ in
                guard !dataReceived else { return }
                dataReceived = true
                
                print("📡 ESP32 data received, ending background scan early")
                
                // 早期終了（データ受信後2秒待機して追加データを取得）
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
                    timer?.cancel()
                    bluetoothService.stopScanning()
                    self.saveLatestDataToUserDefaults(bluetoothService.discoveredDevices)
                    print("✅ Background sensor scan completed (early termination)")
                    task.setTaskCompleted(success: true)
                }
            }
            
            // 最大スキャン時間のタイマー設定
            timer = DispatchWorkItem {
                dataReceivedCancellable.cancel()
                bluetoothService.stopScanning()
                self.saveLatestDataToUserDefaults(bluetoothService.discoveredDevices)
                print("✅ Background sensor scan completed (timeout)")
                task.setTaskCompleted(success: !bluetoothService.discoveredDevices.isEmpty)
            }
            
            // ESP32: 15秒間隔起動、150ms間広告（30ms間隔×5回）
            // バックグラウンドスキャン時間: 18秒（ESP32の1サイクル+余裕）
            // 受信保証: 18秒あれば必ず1回のESP32広告期間を捕捉可能
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 18.0, execute: timer!)
        }
    }
    
    private func saveLatestDataToUserDefaults(_ discoveredDevices: [String: SensorData]) {
        guard let latestData = discoveredDevices.values.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(latestData)
            UserDefaults.standard.set(data, forKey: "latestSensorData")
            UserDefaults.standard.set(Date(), forKey: "latestSensorDataTimestamp")
            
            print("💾 Saved latest sensor data to UserDefaults")
            
            // Schedule a local notification if significant change detected
            scheduleDataUpdateNotification(for: latestData)
            
        } catch {
            print("❌ Failed to save sensor data: \(error)")
        }
    }
    
    private func scheduleDataUpdateNotification(for sensorData: SensorData) {
        let content = UNMutableNotificationContent()
        content.title = "センサーデータ更新"
        content.body = "温度: \(sensorData.formattedTemperature), 湿度: \(sensorData.formattedHumidity)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "sensorDataUpdate", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("📬 Sensor data notification scheduled")
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("📱 Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
    
    // テスト用: 手動でバックグラウンドデータを保存
    func saveTestDataForBackgroundTesting() {
        let testData = SensorData(
            timestamp: Date(),
            deviceAddress: "test-device",
            deviceName: "Test ESP32",
            rssi: -75,
            deviceId: 80,
            readingId: 999,
            temperatureCelsius: 25.5,
            humidityPercent: 60.0,
            pressureHPa: 1013.25,
            voltageVolts: 3.3,
            groupedCount: 1,
            isFromBackground: true
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(testData)
            UserDefaults.standard.set(data, forKey: "latestSensorData")
            UserDefaults.standard.set(Date(), forKey: "latestSensorDataTimestamp")
            print("🧪 Test data saved for background testing")
        } catch {
            print("❌ Failed to save test data: \(error)")
        }
    }
    
    private func getBackgroundTaskErrorMessage(_ error: NSError) -> String {
        switch error.code {
        case 1:
            return "BGTaskSchedulerError.unavailable - Background tasks are not available"
        case 2:
            return "BGTaskSchedulerError.tooManyPendingTaskRequests - Too many pending requests"
        case 3:
            return "BGTaskSchedulerError.notPermitted - Background tasks not permitted (check Info.plist)"
        default:
            return "Unknown error code \(error.code): \(error.localizedDescription)"
        }
    }
    
    // Foreground background task for app suspension
    func beginBackgroundTask() {
        // End any existing background task first
        endBackgroundTask()
        
        print("🔄 Starting foreground background task")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("⏰ Foreground background task expired, ending task")
            self?.endBackgroundTask()
        }
        
        // Set a timer to automatically end the task after a reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            if self?.backgroundTask != .invalid {
                print("⏱️ Auto-ending foreground background task after 25 seconds")
                self?.endBackgroundTask()
            }
        }
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            print("✅ Ending foreground background task")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// Extension to load saved data
extension BackgroundTaskManager {
    func loadLatestSensorData() -> SensorData? {
        guard let data = UserDefaults.standard.data(forKey: "latestSensorData") else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SensorData.self, from: data)
        } catch {
            print("❌ Failed to load sensor data: \(error)")
            return nil
        }
    }
    
    func getLatestDataTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: "latestSensorDataTimestamp") as? Date
    }
}
