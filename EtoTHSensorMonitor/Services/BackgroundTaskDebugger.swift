import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskDebugger {
    static let shared = BackgroundTaskDebugger()
    
    private init() {}
    
    /// バックグラウンドタスクの状態をログ出力
    func logBackgroundTaskStatus() {
        print("🔍 === Background Task Status ===")
        
        // アプリの状態
        let appState = UIApplication.shared.applicationState
        print("📱 App State: \(getAppStateDescription(appState))")
        
        // Background App Refresh設定状態
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        print("🔄 Background Refresh Status: \(getBackgroundRefreshDescription(backgroundRefreshStatus))")
        
        // バックグラウンド残り時間（フォアグラウンドタスク用）
        let backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
        if backgroundTimeRemaining > 0 {
            print("⏰ Background Time Remaining: \(backgroundTimeRemaining) seconds")
        } else {
            print("⏰ Background Time Remaining: \(backgroundTimeRemaining) (app is in foreground)")
        }
        
        print("=== End Status ===")
    }
    
    /// バックグラウンド更新の許可状況を確認
    func checkBackgroundAppRefreshPermission() {
        let status = UIApplication.shared.backgroundRefreshStatus
        
        switch status {
        case .available:
            print("✅ Background App Refresh: Available")
        case .denied:
            print("❌ Background App Refresh: Denied by user")
        case .restricted:
            print("⚠️ Background App Refresh: Restricted")
        @unknown default:
            print("❓ Background App Refresh: Unknown status")
        }
    }
    
    /// 保存されたバックグラウンドデータの最終更新時刻を確認
    func checkLastBackgroundUpdate() {
        if let lastUpdate = BackgroundTaskManager.shared.getLatestDataTimestamp() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            
            print("📅 Last Background Update: \(formatter.string(from: lastUpdate))")
            print("⏱️ Time Since Last Update: \(Int(timeSinceUpdate)) seconds ago")
            
            if timeSinceUpdate > 3600 { // 1時間以上
                print("⚠️ Background update may not be working properly")
            }
        } else {
            print("❓ No background data found")
        }
    }
    
    private func getAppStateDescription(_ state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "Active (Foreground)"
        case .inactive:
            return "Inactive (Transitioning)"
        case .background:
            return "Background"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getBackgroundRefreshDescription(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }
}
