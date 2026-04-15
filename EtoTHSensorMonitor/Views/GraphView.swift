import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: SensorViewModel
    
    @State private var dataSourceType: DataSourceType = .currentSession
    @State private var selectedLogDate: Date? = nil
    @State private var selectedMetric: SensorMetric = .temperature
    @State private var selectedDeviceId: UInt8? = nil // nil = すべて

    init(
        viewModel: SensorViewModel,
        initialDataSourceType: DataSourceType = .currentSession,
        initialLogDate: Date? = nil,
        initialMetric: SensorMetric = .temperature,
        initialDeviceId: UInt8? = nil
    ) {
        self.viewModel = viewModel
        _dataSourceType = State(initialValue: initialDataSourceType)
        _selectedLogDate = State(initialValue: initialLogDate)
        _selectedMetric = State(initialValue: initialMetric)
        _selectedDeviceId = State(initialValue: initialDeviceId)
    }
    
    enum DataSourceType: String, CaseIterable {
        case currentSession = "直近セッション"
        case pastLog = "過去ログ"
    }
    
    enum SensorMetric: String, CaseIterable {
        case temperature = "温度"
        case humidity = "湿度"
        case pressure = "気圧"
        case illuminance = "照度"
        case voltage = "電圧"
        
        var unit: String {
            switch self {
            case .temperature: return "°C"
            case .humidity: return "%"
            case .pressure: return "hPa"
            case .illuminance: return "lx"
            case .voltage: return "V"
            }
        }
        
        var color: Color {
            switch self {
            case .temperature: return .red
            case .humidity: return .blue
            case .pressure: return .orange
            case .illuminance: return .yellow
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
        GeometryReader { geometry in
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
                            if geometry.size.width > 400 {
                                // 画面幅が広い場合（iPad, 横向き等）はセグメント（ラジオボタン風）
                                Picker("表示データ", selection: $selectedMetric) {
                                    ForEach(SensorMetric.allCases, id: \.self) { metric in
                                        Text(metric.rawValue).tag(metric)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            } else {
                                // 画面幅が狭い場合（iPhone縦持ち等）はメニュー
                                Picker("表示データ", selection: $selectedMetric) {
                                    ForEach(SensorMetric.allCases, id: \.self) { metric in
                                        Text(metric.rawValue).tag(metric)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
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
                            // 線を描画
                            LineMark(
                                x: .value("時刻", item.timestamp),
                                y: .value(selectedMetric.rawValue, valueFor(metric: selectedMetric, item: item))
                            )
                            .foregroundStyle(by: .value("Device", "ID: \(item.deviceId)"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            // 計測点を丸で表示
                            PointMark(
                                x: .value("時刻", item.timestamp),
                                y: .value(selectedMetric.rawValue, valueFor(metric: selectedMetric, item: item))
                            )
                            .foregroundStyle(by: .value("Device", "ID: \(item.deviceId)"))
                            .symbolSize(20) // 丸のサイズ調整
                            
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
                        .modifier(ChartYScaleModifier(metric: selectedMetric))
                        // Y軸の目盛を調整
                        .chartYAxis {
                            switch selectedMetric {
                            case .temperature:
                                AxisMarks(values: Array(stride(from: -10, through: 50, by: 5))) { value in
                                    if let number = value.as(Int.self) {
                                        // 10度ごとに濃い線、それ以外は薄い線
                                        let isMajor = number % 10 == 0
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                            .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                        AxisTick()
                                        AxisValueLabel("\(number)")
                                    }
                                }
                            case .pressure:
                                AxisMarks(values: Array(stride(from: 860, through: 1150, by: 20))) { value in
                                    if let number = value.as(Int.self) {
                                        // 100hPaごとに濃い線
                                        let isMajor = number % 100 == 0
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                            .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                        AxisTick()
                                        AxisValueLabel("\(number)")
                                    }
                                }
                            case .voltage:
                                AxisMarks(values: Array(stride(from: 1.0, through: 4.5, by: 0.2))) { value in
                                    if let number = value.as(Double.self) {
                                        // 1.0Vごとに濃い線 (浮動小数点の誤差を考慮)
                                        let isMajor = abs(number.remainder(dividingBy: 1.0)) < 0.01
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                            .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                        AxisTick()
                                        AxisValueLabel(String(format: "%.1f", number))
                                    }
                                }
                            case .humidity:
                                AxisMarks(values: Array(stride(from: 0, through: 100, by: 10))) { value in
                                    if let number = value.as(Int.self) {
                                        // 50%ごとに濃い線、それ以外は薄い線
                                        let isMajor = number % 50 == 0
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                            .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                        AxisTick()
                                        AxisValueLabel("\(number)")
                                    }
                                }
                            case .illuminance:
                                AxisMarks(values: [1, 10, 100, 1_000, 10_000, 54_000]) { value in
                                    if let number = value.as(Int.self) {
                                        let isMajor = (number == 1 || number == 10 || number == 100 || number == 1_000 || number == 10_000)
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                            .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                        AxisTick()
                                        AxisValueLabel("\(number)")
                                    }
                                }
                            }
                        }
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
    }
    
    // 指標に基づく値の取得
    private func valueFor(metric: SensorMetric, item: SensorData) -> Double {
        switch metric {
        case .temperature: return item.temperatureCelsius
        case .humidity: return item.humidityPercent
        case .pressure: return item.pressureHPa
        case .illuminance:
            // 対数軸で0は扱えないので下限を1lxにする
            return max(1.0, item.illuminanceLux ?? 0.0)
        case .voltage: return item.voltageVolts
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // グラフのY軸の範囲をメトリクスごとに指定
    private static func yAxisDomain(for metric: SensorMetric) -> ClosedRange<Double> {
        switch metric {
        case .temperature:
            return -10...50
        case .humidity:
            return 0...100
        case .pressure:
            return 850...1150 // 1000±150
        case .illuminance:
            return 1...54_000
        case .voltage:
            return 1.0...4.5
        }
    }

    private struct ChartYScaleModifier: ViewModifier {
        let metric: SensorMetric

        func body(content: Content) -> some View {
            if metric == .illuminance {
                if #available(iOS 17.0, macOS 14.0, *) {
                    content.chartYScale(domain: 1...54_000, type: .log)
                } else {
                    // 古いOSでは線形軸にフォールバック
                    content.chartYScale(domain: 1...54_000)
                }
            } else {
                content.chartYScale(domain: GraphView.yAxisDomain(for: metric))
            }
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
