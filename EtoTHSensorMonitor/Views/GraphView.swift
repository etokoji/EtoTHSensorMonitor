import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: SensorViewModel
    
    @State private var dataSourceType: DataSourceType = .currentSession
    @State private var selectedLogDate: Date? = nil
    @State private var selectedMetric: SensorMetric = .temperature
    @State private var selectedDeviceId: UInt8? = nil // nil = すべて
    @State private var illuminanceLogScaleEnabled: Bool = true

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

    private var selectedMetricYAxisDomain: ClosedRange<Double> {
        switch selectedMetric {
        case .pressure:
            let values = chartData.map { valueFor(metric: .pressure, item: $0) }
            return Self.pressureAdaptiveYAxisDomain(values: values)
        case .voltage:
            let values = chartData.map { valueFor(metric: .voltage, item: $0) }
            return Self.dynamicYAxisDomain(for: .voltage, values: values) ?? Self.yAxisDomain(for: .voltage)
        case .illuminance:
            // 対数/線形は ChartYScaleModifier 側で分岐（type: .log の都合）
            return Self.yAxisDomain(for: selectedMetric)
        default:
            return Self.yAxisDomain(for: selectedMetric)
        }
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
                        HStack(alignment: .center, spacing: 12) {
                            Text("\(selectedMetric.rawValue) (\(selectedMetric.unit))")
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedMetric == .illuminance {
                                // Toggle 単体だと HStack 内で横方向に広がり、iOS ではラベルとスイッチが大きく離れる
                                HStack(spacing: 8) {
                                    Text("対数軸")
                                        .font(.subheadline)
                                    Toggle("", isOn: $illuminanceLogScaleEnabled)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                }
                                .disabled(!supportsIlluminanceLogScale)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("照度の縦軸を対数軸にする")
                            }
                        }
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
                        .modifier(ChartYScaleModifier(metric: selectedMetric, yAxisDomain: selectedMetricYAxisDomain, illuminanceLogScaleEnabled: illuminanceLogScaleEnabled && supportsIlluminanceLogScale))
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
                                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let number = value.as(Double.self) {
                                        AxisValueLabel(String(format: "%.0f", number))
                                    }
                                }
                            case .voltage:
                                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let number = value.as(Double.self) {
                                        AxisValueLabel(String(format: "%.2f", number))
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
                                if illuminanceLogScaleEnabled && supportsIlluminanceLogScale {
                                    AxisMarks(values: [1, 10, 100, 1_000, 10_000, 54_000]) { value in
                                        if let number = value.as(Int.self) {
                                            let isMajor = (number == 1 || number == 10 || number == 100 || number == 1_000 || number == 10_000)
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                                .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                            AxisTick()
                                            AxisValueLabel("\(number)")
                                        }
                                    }
                                } else {
                                    AxisMarks(values: [0, 10_000, 20_000, 30_000, 40_000, 54_000]) { value in
                                        if let number = value.as(Int.self) {
                                            let isMajor = (number % 20_000 == 0)
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: isMajor ? 1 : 0.5))
                                                .foregroundStyle(isMajor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1))
                                            AxisTick()
                                            AxisValueLabel("\(number)")
                                        }
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
            .onChange(of: dataSourceType) { _, newValue in
                guard newValue == .pastLog else { return }
                refreshTodayPastLogIfNeeded()
            }
        }
        }
    }

    private func refreshTodayPastLogIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())

        // 日付一覧が古い可能性があるので先に更新
        viewModel.loadAvailableDates()

        if let date = selectedLogDate, Calendar.current.isDate(date, inSameDayAs: today) {
            viewModel.loadReadings(for: date)
            return
        }

        // まだ日付が未選択の場合は、利用可能な先頭日付を選ぶ（初期表示と同じ挙動）
        if selectedLogDate == nil, let firstDate = viewModel.availableLogDates.first {
            selectedLogDate = firstDate
            if Calendar.current.isDate(firstDate, inSameDayAs: today) {
                viewModel.loadReadings(for: firstDate)
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
            // 対数軸で0は扱えないので、対数時のみ下限を1lxにする
            if illuminanceLogScaleEnabled && supportsIlluminanceLogScale {
                return max(1.0, item.illuminanceLux ?? 0.0)
            }
            return item.illuminanceLux ?? 0.0
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

    private static func dynamicYAxisDomain(for metric: SensorMetric, values: [Double]) -> ClosedRange<Double>? {
        let finite = values.filter { $0.isFinite }
        guard !finite.isEmpty else { return nil }

        let sorted = finite.sorted()
        let p5 = percentile(sorted, p: 0.05)
        let p50 = percentile(sorted, p: 0.50)
        let p95 = percentile(sorted, p: 0.95)

        let baseLow = min(p5, p95)
        let baseHigh = max(p5, p95)
        let span = baseHigh - baseLow

        let step: Double
        let minPad: Double
        let minSpan: Double
        let clampLow: Double?

        switch metric {
        case .voltage:
            step = 0.05
            minPad = 0.05
            minSpan = 0.3
            clampLow = 0.0
        default:
            return nil
        }

        let pad = max(span * 0.10, minPad)
        let finalSpan = max(span + 2 * pad, minSpan)

        var low = p50 - finalSpan / 2
        var high = p50 + finalSpan / 2

        // 丸め（軸が細かく変わりすぎないように）
        low = floor(low / step) * step
        high = ceil(high / step) * step

        if let clampLow {
            low = max(clampLow, low)
            if high <= low {
                high = low + step
            }
        }

        return low...high
    }

    private static func pressureAdaptiveYAxisDomain(values: [Double]) -> ClosedRange<Double> {
        // 通常は固定レンジ（見やすさ優先）
        let fixedLow = 960.0
        let fixedHigh = 1050.0
        let fixed = fixedLow...fixedHigh

        let finite = values.filter { $0.isFinite }
        guard !finite.isEmpty else { return fixed }

        // 直近が連続して固定範囲外なら、そのときだけ動的に調整する
        // - たまの外れ値では軸を動かさない
        let consecutiveThreshold = 3
        var lowStreak = 0
        var highStreak = 0
        for v in finite.reversed() {
            if v < fixedLow {
                lowStreak += 1
                break
            }
            if v > fixedHigh {
                highStreak += 1
                break
            }
            // 直近が範囲内になった時点で連続は途切れる
            break
        }

        // 直近1点だけでは「連続」を判断できないので、末尾から同方向に続く分だけ数える
        if let last = finite.last {
            if last < fixedLow {
                lowStreak = 0
                for v in finite.reversed() {
                    if v < fixedLow { lowStreak += 1 } else { break }
                }
            } else if last > fixedHigh {
                highStreak = 0
                for v in finite.reversed() {
                    if v > fixedHigh { highStreak += 1 } else { break }
                }
            } else {
                return fixed
            }
        }

        guard max(lowStreak, highStreak) >= consecutiveThreshold else {
            return fixed
        }

        // 動的化する場合も「通常域の見やすさ」を優先して分位ベースでレンジを作る
        // ただし丸めは気圧向けに 0.5hPa 刻み
        let sorted = finite.sorted()
        let p5 = percentile(sorted, p: 0.05)
        let p50 = percentile(sorted, p: 0.50)
        let p95 = percentile(sorted, p: 0.95)

        let baseLow = min(p5, p95)
        let baseHigh = max(p5, p95)
        let span = baseHigh - baseLow

        let step = 0.5
        let minPad = 0.2
        let minSpan = 10.0
        let clampLow = 800.0

        let pad = max(span * 0.10, minPad)
        let finalSpan = max(span + 2 * pad, minSpan)

        var low = p50 - finalSpan / 2
        var high = p50 + finalSpan / 2

        low = floor(low / step) * step
        high = ceil(high / step) * step

        low = max(clampLow, low)
        if high <= low {
            high = low + step
        }

        return low...high
    }

    private static func percentile(_ sorted: [Double], p: Double) -> Double {
        precondition(!sorted.isEmpty)
        if sorted.count == 1 { return sorted[0] }

        let clampedP = min(max(p, 0.0), 1.0)
        let pos = clampedP * Double(sorted.count - 1)
        let lower = Int(floor(pos))
        let upper = Int(ceil(pos))

        if lower == upper { return sorted[lower] }
        let weight = pos - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private var supportsIlluminanceLogScale: Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return true
        }
        return false
    }

    private struct ChartYScaleModifier: ViewModifier {
        let metric: SensorMetric
        let yAxisDomain: ClosedRange<Double>
        let illuminanceLogScaleEnabled: Bool

        func body(content: Content) -> some View {
            if metric == .illuminance {
                if illuminanceLogScaleEnabled {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        content.chartYScale(domain: 1...54_000, type: .log)
                    } else {
                        content.chartYScale(domain: 1...54_000)
                    }
                } else {
                    content.chartYScale(domain: 0...54_000)
                }
            } else {
                content.chartYScale(domain: yAxisDomain)
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
