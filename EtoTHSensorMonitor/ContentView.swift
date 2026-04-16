import SwiftUI

struct ContentView: View {
    @StateObject private var sharedViewModel = SensorViewModel()
    @State private var showingSettings = false
    @State private var isAppActive = true
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView {
            NavigationStack {
                ZStack {
                    HomeView(viewModel: sharedViewModel)
                    
                    // Data received indicator positioned at top-left
                    if sharedViewModel.showDataReceivedIndicator {
                        VStack {
                            HStack {
                                DataReceivedIndicator()
                                    .padding(.leading, 16)
                                    .padding(.top, 8)
                                Spacer()
                            }
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("ホーム")
            }
            
            GraphView(viewModel: sharedViewModel)
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                        Text("グラフ")
                }
                
            HistoryView(viewModel: sharedViewModel)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("履歴")
                }
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: sharedViewModel)
        }
        .onAppear {
            #if os(iOS)
            // タブバーの見た目をカスタマイズ（iOS only）
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemGray6
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
            tabBarAppearance.shadowColor = UIColor.systemGray4
            tabBarAppearance.shadowImage = UIImage()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            #endif
            
            print("🚀 App started - initializing bluetooth scanning")
            sharedViewModel.startScanning()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                print("📱 App became active")
                isAppActive = true
                handleAppBecameActive()
            case .background:
                print("📱 App entered background")
                isAppActive = false
                handleAppEnteredBackground()
            case .inactive:
                print("📱 App will resign active")
                isAppActive = false
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - App Lifecycle Methods
    
    private func handleAppBecameActive() {
        print("🔄 Handling app became active")
        
        // フォアグラウンド復帰処理
        sharedViewModel.dataService.handleEnterForeground()

        // 過去ログで「本日」を表示中なら、追記された分を再読み込み
        sharedViewModel.refreshTodayLogIfNeeded()
        
        // Bluetoothスキャンが停止している場合、再開してみる
        if !sharedViewModel.isScanning {
            print("📥 Bluetooth not scanning, restarting scan")
            sharedViewModel.startScanning()
        }
    }
    
    private func handleAppEnteredBackground() {
        print("🔄 Handling app entered background")
        
        // バックグラウンドでもBLEスキャンを継続
        sharedViewModel.dataService.handleEnterBackground()
        
        #if os(iOS)
        // BGTaskSchedulerでバックグラウンドリフレッシュをスケジュール
        AppDelegate.scheduleBLERefreshTask()
        #endif
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var isLandscape = false
    @State private var dataSourceType: DataSourceType = .currentSession
    @State private var selectedLogDate: Date? = nil
    
    enum DataSourceType: String, CaseIterable {
        case currentSession = "直近セッション"
        case pastLog = "過去ログ"
    }
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
    
    // 現在選択されているデータソースの生データ
    private var listData: [SensorData] {
        if dataSourceType == .currentSession {
            return viewModel.sensorReadings
        } else {
            return viewModel.selectedDateReadings
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
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
                        } else {
                            // 直近セッション時のクリアボタン等
                            HStack {
                                Text("データ件数: \(listData.count)件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !listData.isEmpty {
                                    Button("クリア") {
                                        viewModel.clearReadings()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // データ一覧領域
                    if listData.isEmpty {
                        Spacer()
                        emptyStateView
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: isLandscape ? 3 : 6) {
                                ForEach(listData) { reading in
                                    SensorReadingView(
                                        sensorData: reading,
                                        isHighlighted: dataSourceType == .currentSession && viewModel.highlightedReadingIds.contains(reading.id),
                                        isLandscapeCompact: isLandscape || isIPad
                                    )
                                    .opacity(dataSourceType == .pastLog ? 0.8 : 1.0)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Data received indicator（左上に表示）
                if viewModel.showDataReceivedIndicator {
                    VStack {
                        HStack {
                            DataReceivedIndicator()
                                .padding(.leading, 16)
                                .padding(.top, 8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("センサー履歴")
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
        }
        .onAppear {
            print("📥 HistoryView appeared - scanning status: \(viewModel.isScanning)")
            if !viewModel.isScanning {
                print("⚠️ Scanning not active, starting from HistoryView")
                viewModel.startScanning()
            }
            updateOrientation()
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
        #endif
        .alert("ブルートゥースアクセスが拒否されました", isPresented: $viewModel.showBluetoothUnauthorizedAlert) {
            Button("設定を開く") {
                #if os(iOS)
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
                #endif
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このアプリがセンサーデータを受信するためには、Bluetoothアクセスを許可してください。\n\n設定 > アプリ > 温度センサー表示 > Bluetooth で設定できます。")
        }
        .onChange(of: dataSourceType) { _, newValue in
            guard newValue == .pastLog else { return }
            refreshTodayPastLogIfNeeded()
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(dataSourceType == .currentSession ? "デバイスを検索中..." : "データなし")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if dataSourceType == .currentSession && !viewModel.isScanning && viewModel.bluetoothState == .poweredOn {
                Button("スキャン開始") {
                    viewModel.startScanning()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func updateOrientation() {
        #if os(iOS)
        let orientation = UIDevice.current.orientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = orientation.isLandscape
        }
        #endif
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
    ContentView()
}
