import SwiftUI
import BackgroundTasks

@main
struct EtoTHSensorMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // App initialization
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate for Background Task Registration
class AppDelegate: NSObject, UIApplicationDelegate {
    static let bleRefreshTaskIdentifier = "com.etokoji.EtoTHSensorMonitor.bleRefresh"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // BGTaskSchedulerにバックグラウンドBLEリフレッシュタスクを登録
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.bleRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleBLERefreshTask(task as! BGAppRefreshTask)
        }
        
        print("🚀 BGTaskScheduler registered for BLE refresh")
        return true
    }
    
    // MARK: - Background Task Handling
    
    private func handleBLERefreshTask(_ task: BGAppRefreshTask) {
        print("📶 BLE refresh background task started")
        
        // 次のバックグラウンドリフレッシュをスケジュール
        AppDelegate.scheduleBLERefreshTask()
        
        // タスクが期限切れになった場合のハンドラ
        task.expirationHandler = {
            print("📶 BLE refresh task expired")
            task.setTaskCompleted(success: false)
        }
        
        // BLEスキャンが継続中であることを確認し、タスクを完了
        // CoreBluetoothの状態復元とbluetooth-centralバックグラウンドモードが
        // 実際のBLEスキャンの継続を担当する
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("📶 BLE refresh task completed")
            task.setTaskCompleted(success: true)
        }
    }
    
    /// バックグラウンドBLEリフレッシュタスクをスケジュール
    static func scheduleBLERefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: bleRefreshTaskIdentifier)
        // 最短15分後に実行（iOSが実際のタイミングを決定）
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📶 BLE refresh task scheduled")
        } catch {
            print("❌ Failed to schedule BLE refresh task: \(error)")
        }
    }
}
