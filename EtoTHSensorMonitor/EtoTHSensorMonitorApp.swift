import SwiftUI

@main
struct EtoTHSensorMonitorApp: App {
    
    init() {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTask()
        BackgroundTaskManager.shared.requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("🌃 App entering background")
                    BackgroundTaskManager.shared.scheduleBackgroundTask()
                    BackgroundTaskManager.shared.beginBackgroundTask()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    print("🌅 App entering foreground")
                    BackgroundTaskManager.shared.endBackgroundTask()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    print("📱 App became active")
                    BackgroundTaskManager.shared.endBackgroundTask()
                }
        }
    }
}
