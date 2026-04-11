import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: SensorViewModel
    
    @State private var dataSourceType: DataSourceType = .currentSession
    @State private var selectedLogDate: Date? = nil
    @State private var selectedMetric: SensorMetric = .temperature
    @State private var selectedDeviceId: UInt8? = nil // nil = すべて
    
    enum DataSourceType: String, CaseIterable {
        case currentSession = "直近セッション"
        case pastLog = "過去ログ"
    }
    
    enum SensorMetric: String, CaseIterable {
        case temperature = "温度"
        case humidity = "湿度"
        case pressure = "気圧"
        case voltage = "電圧"
        
        var unit: String {
            switch self {
            case .temperature: return "°C"
            case .humidity: return "%"
            case .pressure: return "hPa"
            case .voltage: return "V"
            }
        }
        
        var color: Color {
            switch self {
            case .temperature: return .red
            case .humidity: return .blue
            case .pressure: return .orange
            case .voltage: return .green
            }
        }
    }
    
    // 現在選択されているデータソースの生データ
    private var rawData: [SensorData] {
        if dataSourceType == .currentSession {
            return viewModel.sensorReadings
        } else {
            return viewModel.selectedDateReadings
        }
    }
    
    // グラフ表示用に時系列順にソート＆フィルタリングしたデータ
    private var chartData: [SensorData] {
        var data = rawData
        // デバイスのフィルタリング
        if let deviceId = selectedDeviceId {
            data = data.filter { $0.deviceId == deviceId }
        }
        // 古い順にソート（グラフは左から右へ時間が進む）
        return data.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 現在のデータに含まれるユニークなデバイスID
    private var uniqueDeviceIds: [UInt8] {
        Array(Set(rawData.map { $0.deviceId })).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // コントロールパネル
                VStack(spacing: 12) {
                    // データソース切り替え
                    Picker("データソース", selection: $dataSourceType) {
                        ForEach(DataSourceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 過去ログ選択時の日付ピッカー
                    if dataSourceType == .pastLog {
                        HStack {
                            Text("日付:")
                                .foregroundColor(.secondary)
                            
                            if viewModel.availableLogDates.isEmpty {
                                Text("ログなし")
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("日付を選択", selection: $selectedLogDate) {
                                    Text("選択してください").tag(Date?.none)
                                    ForEach(viewModel.availableLogDates, id: \.self) { date in
                                        Text(formattedLogDate(date)).tag(Date?.some(date))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: selectedLogDate) { _, newDate in
                                    if let date = newDate {
                                        viewModel.loadReadings(for: date)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if viewModel.isLoadingDate {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            // 過去ログタブを開いた時に初期選択を設定
                            if selectedLogDate == nil, let firstDate = viewModel.availableLogDates.first {
                                selectedLogDate = firstDate
                                viewModel.loadReadings(for: firstDate)
                            }
                        }
                    }
                    
                    // メトリクスとデバイスの切り替え
                    HStack {
                        Picker("表示データ", selection: $selectedMetric) {
                            ForEach(SensorMetric.allCases, id: \.self) { metric in
                                Text(metric.rawValue).tag(metric)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Spacer()
                        
                        Picker("デバイス", selection: $selectedDeviceId) {
                            Text("すべて").tag(UInt8?.none)
                            ForEach(uniqueDeviceIds, id: \.self) { id in
                                Text("ID: \(id)").tag(UInt8?.some(id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 10)
                
                Divider()
                
                // グラフ領域
                if chartData.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("表示するデータがありません")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading) {
                        Text("\(selectedMetric.rawValue) (\(selectedMetric.unit))")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        Chart(chartData) { item in
                            LineMark(
                                x: .value("時刻", item.timestamp),
                                y: .value(selectedMetric.rawValue, valueFor(metric: selectedMetric, item: item))
                            )
                            // デバイスごとに色分け
                            .foregroundStyle(by: .value("Device", "ID: \(item.deviceId)"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            // 単一デバイス選択時はエリアを塗りつぶす（グラデーション）
                            if selectedDeviceId != nil {
                                AreaMark(
                                    x: .value("時刻", item.timestamp),
                                    y: .value(selectedMetric.rawValue, valueFor(metric: selectedMetric, item: item))
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [selectedMetric.color.opacity(0.3), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                // AreaMark も同じ Device 軸でグループ化させる
                                .foregroundStyle(by: .value("Device", "ID: \(item.deviceId)"))
                            }
                        }
                        // Y軸の値の範囲をメトリクスごとに調整
                        .chartYScale(domain: yAxisDomain(for: selectedMetric))
                        // X軸の時刻フォーマット
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine()
                                AxisTick()
                                if let date = value.as(Date.self) {
                                    AxisValueLabel(formatTime(date))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("グラフ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    ConnectionStatusIndicator(viewModel: viewModel, isCompact: true)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.toggleScanning) {
                        Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(viewModel.isScanning ? .red : .green)
                    }
                }
            }
            .onAppear {
                if !viewModel.isScanning {
                    viewModel.startScanning()
                }
            }
        }
    }
    
    // 指標に基づく値の取得
    private func valueFor(metric: SensorMetric, item: SensorData) -> Double {
        switch metric {
        case .temperature: return item.temperatureCelsius
        case .humidity: return item.humidityPercent
        case .pressure: return item.pressureHPa
        case .voltage: return item.voltageVolts
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // グラフのY軸の範囲をメトリクスごとに指定
    private func yAxisDomain(for metric: SensorMetric) -> ClosedRange<Double> {
        switch metric {
        case .temperature:
            return -10...50
        case .humidity:
            return 0...100
        case .pressure:
            return 850...1150 // 1000±150
        case .voltage:
            return 1.0...4.5
        }
    }
    
    private func formattedLogDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        let today = Calendar.current.isDateInToday(date)
        let yesterday = Calendar.current.isDateInYesterday(date)
        let base = formatter.string(from: date)
        if today { return base + "（本日）" }
        if yesterday { return base + "（昨日）" }
        return base
    }
}

#Preview {
    let viewModel = SensorViewModel()
    // ダミーデータを入れたい場合はviewModelに直接注入する必要がありますが、
    // ここでは空の状態のプレビューを表示します。
    return GraphView(viewModel: viewModel)
}
