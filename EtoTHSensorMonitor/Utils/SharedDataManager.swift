import Foundation
import WidgetKit

/// App Groupを通じてWidget Extensionとデータを共有するクラス
class SharedDataManager {
    static let shared = SharedDataManager()

    static let appGroupID = "group.com.etokoji.EtoTHSensorMonitor"
    static let latestReadingKey = "latestSensorReading"
    static let recentReadingsKey = "recentSensorReadings"
    static let maxRecentCount = 5

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedDataManager.appGroupID)
    }

    private init() {
        debugStatus()
    }

    /// App Groupの動作状況をコンソールに出力
    func debugStatus() {
        if let defaults = sharedDefaults {
            let hasData = defaults.data(forKey: SharedDataManager.latestReadingKey) != nil
            print("📊 App Group OK - latestReading: \(hasData ? "あり" : "なし")")
        } else {
            print("❌ App Group NG - UserDefaults(suiteName:) が nil を返しました")
            print("❌ エンタイトルまたはProvisioning Profileを確認してください")
        }
    }

    // MARK: - 書き込み（メインアプリ側）

    /// 最新のセンサーデータをApp Groupに書き込み、Widgetをリロードする
    func writeLatestReading(_ reading: SensorData) {
        guard let defaults = sharedDefaults else {
            print("⚠️ App Group UserDefaults unavailable - check App Group entitlement")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        // 最新の1件を保存
        if let data = try? encoder.encode(reading) {
            defaults.set(data, forKey: SharedDataManager.latestReadingKey)
        }

        // 直近5件を保存（Widgetのスタック表示用）
        var recent: [SensorData] = readRecentReadings()
        recent.insert(reading, at: 0)
        if recent.count > SharedDataManager.maxRecentCount {
            recent = Array(recent.prefix(SharedDataManager.maxRecentCount))
        }
        if let arrayData = try? encoder.encode(recent) {
            defaults.set(arrayData, forKey: SharedDataManager.recentReadingsKey)
        }

        // Widgetのタイムラインをリロード
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 読み込み（Widget側でも使用）

    /// 最新のセンサーデータを読み込む
    func readLatestReading() -> SensorData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: SharedDataManager.latestReadingKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(SensorData.self, from: data)
    }

    /// 直近のセンサーデータ（最大5件）を読み込む
    func readRecentReadings() -> [SensorData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: SharedDataManager.recentReadingsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([SensorData].self, from: data)) ?? []
    }
}
