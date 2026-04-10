import SwiftUI
#if os(iOS)
import BackgroundTasks
#endif

@main
struct EtoTHSensorMonitorApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
// MARK: - AppDelegate for Background Task Registration (iOS only)
class AppDelegate: NSObject, UIApplicationDelegate {
    static let bleRefreshTaskIdentifier = "com.etokoji.EtoTHSensorMonitor.bleRefresh"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.bleRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleBLERefreshTask(task as! BGAppRefreshTask)
        }
        print("🚀 BGTaskScheduler registered for BLE refresh")
        return true
    }
    
    private func handleBLERefreshTask(_ task: BGAppRefreshTask) {
        print("📥 BLE refresh background task started")
        AppDelegate.scheduleBLERefreshTask()
        task.expirationHandler = {
            print("📥 BLE refresh task expired")
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("📥 BLE refresh task completed")
            task.setTaskCompleted(success: true)
        }
    }
    
    static func scheduleBLERefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: bleRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📥 BLE refresh task scheduled")
        } catch {
            print("❌ Failed to schedule BLE refresh task: \(error)")
        }
    }
}
#endif
