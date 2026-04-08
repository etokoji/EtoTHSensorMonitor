import Foundation

/// センサーデータをJSON Lines形式でファイルに保存・読み込みするクラス
class ReadingLogManager {
    static let shared = ReadingLogManager()

    private let fileManager = FileManager.default
    private let maxDaysToKeep = 30
    private let maxEntriesPerFile = 2000

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
    func append(_ reading: SensorData) {
        let url = logFileURL(for: reading.timestamp)
        guard let line = encode(reading) else { return }
        let lineWithNewline = line + "\n"

        if fileManager.fileExists(atPath: url.path) {
            // ファイルが既にある場合は追記
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                if let data = lineWithNewline.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        } else {
            // 新しいファイルを作成
            try? lineWithNewline.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - 読み込み

    /// 当日のログファイルから既存データを読み込む（アプリ再起動時の復元用）
    func loadTodayReadings() -> [SensorData] {
        let url = logFileURL(for: Date())
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let readings = loadReadings(from: url)
        // 新しい順に並び替え
        return readings.sorted { $0.timestamp > $1.timestamp }
    }

    /// 指定日数分の過去ログを読み込む（本日を除く）
    func loadPastReadings(maxDays: Int = 7) -> [SensorData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var results: [SensorData] = []

        for dayOffset in 1...maxDays {
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "sensor_log_\(formatter.string(from: date)).jsonl"
        return logsDirectory.appendingPathComponent(name)
    }

    private func logDate(from url: URL) -> Date? {
        let name = url.deletingPathExtension().lastPathComponent
        // "sensor_log_yyyy-MM-dd" 形式
        guard name.hasPrefix("sensor_log_") else { return nil }
        let dateStr = String(name.dropFirst("sensor_log_".count))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
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
