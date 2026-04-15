import WidgetKit
import SwiftUI

// MARK: - Shared Models (widgetとメインアプリで共通利用)

/// Widget用センサーデータ（App Group経由で受け取る）
struct WidgetSensorData: Codable {
    let id: UUID
    let timestamp: Date
    let deviceAddress: String
    let deviceName: String?
    let rssi: Int?
    let deviceId: UInt8
    let readingId: UInt16
    let temperatureCelsius: Double
    let humidityPercent: Double
    let pressureHPa: Double
    let voltageVolts: Double
    let illuminanceLux: Double?
    let groupedCount: Int

    var formattedTemperature: String { String(format: "%.1f°C", temperatureCelsius) }
    var formattedHumidity: String    { String(format: "%.1f%%", humidityPercent) }
    var formattedPressure: String    { String(format: "%.1f hPa", pressureHPa) }
    var formattedVoltage: String     { String(format: "%.2fV", voltageVolts) }
    var formattedIlluminance: String {
        if let lux = illuminanceLux { return String(format: "%.1f lx", lux) }
        return "—"
    }
    var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        f.timeZone = .current
        return f.string(from: timestamp)
    }
}

// MARK: - App Group Reader

private struct WidgetDataReader {
    static let appGroupID = "group.com.etokoji.EtoTHSensorMonitor"
    static let latestReadingKey = "latestSensorReading"

    static func readLatest() -> WidgetSensorData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: latestReadingKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSensorData.self, from: data)
    }
}

// MARK: - Timeline Entry

struct SensorEntry: TimelineEntry {
    let date: Date
    let sensorData: WidgetSensorData?
}

// MARK: - Timeline Provider

struct SensorWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SensorEntry {
        SensorEntry(
            date: Date(),
            sensorData: WidgetSensorData(
                id: UUID(),
                timestamp: Date(),
                deviceAddress: "AA:BB:CC:DD:EE:FF",
                deviceName: "ESP32-ENV-01",
                rssi: -60,
                deviceId: 1,
                readingId: 1,
                temperatureCelsius: 23.5,
                humidityPercent: 55.0,
                pressureHPa: 1013.2,
                voltageVolts: 3.7,
                illuminanceLux: 456.7,
                groupedCount: 1
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SensorEntry) -> Void) {
        let entry = SensorEntry(date: Date(), sensorData: WidgetDataReader.readLatest())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SensorEntry>) -> Void) {
        let entry = SensorEntry(date: Date(), sensorData: WidgetDataReader.readLatest())
        // アプリがデータを更新するたびにWidgetCenter.reloadAllTimelines()が呼ばれるので
        // ここでは1時間後の自動更新を設定
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct SensorWidgetEntryView: View {
    var entry: SensorEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            mainContent
                .containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let data = entry.sensorData {
            switch family {
            case .systemSmall:
                smallView(data: data)
            case .systemMedium:
                mediumView(data: data)
            case .systemLarge:
                largeView(data: data)
            case .accessoryCircular:
                accessoryCircularView(data: data)
            case .accessoryRectangular:
                accessoryRectangularView(data: data)
            case .accessoryInline:
                accessoryInlineView(data: data)
            default:
                smallView(data: data)
            }
        } else {
            noDataView
        }
    }

    // MARK: Small Widget (2x2)
    private func smallView(data: WidgetSensorData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                    .font(.caption2)
                Text("ID:\(data.deviceId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            // 温度（大きく表示）
            VStack(alignment: .leading, spacing: 2) {
                Label("温度", systemImage: "thermometer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(data.formattedTemperature)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }

            // 湿度
            VStack(alignment: .leading, spacing: 2) {
                Label("湿度", systemImage: "humidity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(data.formattedHumidity)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(data.formattedTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(12)
    }

    // MARK: Medium Widget (4x2)
    private func mediumView(data: WidgetSensorData) -> some View {
        HStack(spacing: 16) {
            // 左: 温度・湿度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                        .font(.caption2)
                    Text("ID:\(data.deviceId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ValueRow(icon: "thermometer", label: "温度",
                         value: data.formattedTemperature, color: .red)
                ValueRow(icon: "humidity", label: "湿度",
                         value: data.formattedHumidity, color: .blue)
            }

            Divider()

            // 右: 気圧・電圧・時刻
            VStack(alignment: .leading, spacing: 6) {
                Text(data.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Spacer()

                ValueRow(icon: "barometer", label: "気圧",
                         value: data.formattedPressure, color: .orange)
                ValueRow(icon: "battery.100", label: "電圧",
                         value: data.formattedVoltage, color: .green)
                ValueRow(icon: "sun.max", label: "照度",
                         value: data.formattedIlluminance, color: .yellow)
            }
        }
        .padding(12)
    }

    // MARK: Large Widget (4x4)
    private func largeView(data: WidgetSensorData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Label("センサーモニター", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("ID:\(data.deviceId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 4つのセンサー値
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                LargeSensorCard(icon: "thermometer", label: "温度",
                                value: data.formattedTemperature, color: .red)
                LargeSensorCard(icon: "humidity", label: "湿度",
                                value: data.formattedHumidity, color: .blue)
                LargeSensorCard(icon: "barometer", label: "気圧",
                                value: data.formattedPressure, color: .orange)
                LargeSensorCard(icon: "battery.100", label: "電圧",
                                value: data.formattedVoltage, color: .green)
                LargeSensorCard(icon: "sun.max", label: "照度",
                                value: data.formattedIlluminance, color: .yellow)
            }

            Spacer()

            // フッター
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(data.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: Lock Screen - Circular
    private func accessoryCircularView(data: WidgetSensorData) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "thermometer")
                .font(.caption2)
            Text(String(format: "%.0f°", data.temperatureCelsius))
                .font(.headline)
                .fontWeight(.bold)
        }
    }

    // MARK: Lock Screen - Rectangular
    private func accessoryRectangularView(data: WidgetSensorData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("センサー ID:\(data.deviceId)")
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Label(data.formattedTemperature, systemImage: "thermometer")
                    .font(.caption)
                Label(data.formattedHumidity, systemImage: "humidity")
                    .font(.caption)
            }
        }
    }

    // MARK: Lock Screen - Inline
    private func accessoryInlineView(data: WidgetSensorData) -> some View {
        Label("\(data.formattedTemperature) / \(data.formattedHumidity)",
              systemImage: "thermometer")
    }

    // MARK: No Data
    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("データなし")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("アプリを起動して\nスキャンしてください")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Subviews

private struct ValueRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 16)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

private struct LargeSensorCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Widget Definition

@main
struct EtoTHSensorWidgetBundle: WidgetBundle {
    var body: some Widget {
        EtoTHSensorWidget()
    }
}

struct EtoTHSensorWidget: Widget {
    let kind = "EtoTHSensorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SensorWidgetProvider()) { entry in
            SensorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("センサーモニター")
        .description("ESP32センサーの最新データを表示")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
