import Foundation

/// センサーデータをJSON Lines形式でファイルに保存・読み込みするクラス
class ReadingLogManager {
    static let shared = ReadingLogManager()
    
    static let didCreateNewLogFileNotification = Notification.Name("ReadingLogManager.didCreateNewLogFile")
    static let notificationKeyLogFileURL = "logFileURL"

    private let fileManager = FileManager.default
    private let maxDaysToKeep = 30
    private let maxEntriesPerFile = 2000
    
    // yyyy-MM-dd は固定フォーマットなので locale/timeZone を固定して扱う
    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // ログファイルを格納するディレクトリ
    private var logsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SensorLogs", isDirectory: true)
    }

    private init() {
        createLogsDirectoryIfNeeded()
        cleanupOldFiles()
    }

    // MARK: - 書き込み

    /// センサーデータをその日のログファイルに追記する
    /// - Note: ファイルの「日付」は受信時刻（端末ローカル）で切り替える。
    ///         センサ側時刻が未設定/固定でも日付跨ぎで確実に新ファイルへ切り替わるようにする。
    func append(_ reading: SensorData, receivedAt: Date = Date()) {
        createLogsDirectoryIfNeeded()
        let url = logFileURL(for: receivedAt)
        let existedBeforeWrite = fileManager.fileExists(atPath: url.path)
        guard let line = encode(reading) else { return }
        let lineWithNewline = line + "\n"

        do {
            if existedBeforeWrite {
                // ファイルが既にある場合は追記
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = lineWithNewline.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } else {
                // 新しいファイルを作成
                try lineWithNewline.write(to: url, atomically: true, encoding: .utf8)
                NotificationCenter.default.post(
                    name: Self.didCreateNewLogFileNotification,
                    object: nil,
                    userInfo: [Self.notificationKeyLogFileURL: url]
                )
            }
        } catch {
            print("❌ Failed to append log: \(error) url=\(url.lastPathComponent)")
        }
    }

    // MARK: - 読み込み

    /// 指定した1日分のデータを読み込む
    func loadDayReadings(for date: Date) -> [SensorData] {
        let url = logFileURL(for: date)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return loadReadings(from: url).sorted { $0.timestamp > $1.timestamp }
    }

    /// 指定日数分のログを読み込む
    /// - Parameters:
    ///   - maxDays: 読み込む日数（本日を含む場合は当日もカウント）
    ///   - includeToday: true の場合は本日のファイルも含める
    func loadPastReadings(maxDays: Int = 7, includeToday: Bool = false) -> [SensorData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOffset = includeToday ? 0 : 1

        var results: [SensorData] = []

        for dayOffset in startOffset...maxDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let url = logFileURL(for: date)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let readings = loadReadings(from: url)
            results.append(contentsOf: readings)
        }

        // 新しい順に並び替え
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    /// 利用可能なログ日付一覧を返す
    func availableLogDates() -> [Date] {
        guard let files = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { logDate(from: $0) }.sorted(by: >)
    }

    // MARK: - Private helpers

    private func createLogsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
    }

    private func cleanupOldFiles() {
        guard let files = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -maxDaysToKeep, to: Date())!

        for file in files {
            if let date = logDate(from: file), date < cutoff {
                try? fileManager.removeItem(at: file)
                print("📝 Old log deleted: \(file.lastPathComponent)")
            }
        }
    }

    private func logFileURL(for date: Date) -> URL {
        let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
        let name = "sensor_log_\(Self.fileDateFormatter.string(from: day)).jsonl"
        return logsDirectory.appendingPathComponent(name)
    }

    private func logDate(from url: URL) -> Date? {
        let name = url.deletingPathExtension().lastPathComponent
        // "sensor_log_yyyy-MM-dd" 形式
        guard name.hasPrefix("sensor_log_") else { return nil }
        let dateStr = String(name.dropFirst("sensor_log_".count))
        return Self.fileDateFormatter.date(from: dateStr)
    }

    private func loadReadings(from url: URL) -> [SensorData] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: .newlines)
        var results: [SensorData] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let reading = decode(trimmed) {
                results.append(reading)
            }
        }
        // 最新のエントリーが多すぎる場合は制限
        if results.count > maxEntriesPerFile {
            return Array(results.suffix(maxEntriesPerFile))
        }
        return results
    }

    private func encode(_ reading: SensorData) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(reading) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decode(_ jsonString: String) -> SensorData? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(SensorData.self, from: data)
    }
}
