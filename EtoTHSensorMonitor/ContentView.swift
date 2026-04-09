import SwiftUI

struct ContentView: View {
    @StateObject private var sharedViewModel = SensorViewModel()
    @State private var showingSettings = false
    @State private var isAppActive = true
    
    var body: some View {
        TabView {
            NavigationStack {
                ZStack {
                    HomeView(viewModel: sharedViewModel)
                    
                    // Data received indicator positioned relative to toolbar
                    if sharedViewModel.showDataReceivedIndicator {
                        VStack {
                            HStack {
                                Spacer()
                                DataReceivedIndicator()
                                    .padding(.trailing, 60) // 歯車アイコンの左に配置
                            }
                            .padding(.top, -35) // ナビゲーションバーの高さに合わせて調整
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
            // タブバーの見た目をカスタマイズ
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemGray6 // 背景色を設定
            
            // 選択されていないタブの色
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            
            // 選択されたタブの色
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
            
            // 上部に境界線を追加
            tabBarAppearance.shadowColor = UIColor.systemGray4
            tabBarAppearance.shadowImage = UIImage()
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            // アプリ起動時にグローバルにスキャンを開始
            print("🚀 App started - initializing bluetooth scanning")
            sharedViewModel.startScanning()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("📱 App will enter foreground")
            isAppActive = true
            handleAppBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            print("📱 App entered background")
            isAppActive = false
            handleAppEnteredBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 App became active")
            isAppActive = true
            handleAppBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App will resign active")
            isAppActive = false
        }
    }
    
    // MARK: - App Lifecycle Methods
    
    private func handleAppBecameActive() {
        print("🔄 Handling app became active")
        
        // フォアグラウンド復帰処理
        sharedViewModel.dataService.handleEnterForeground()
        
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
        
        // BGTaskSchedulerでバックグラウンドリフレッシュをスケジュール
        AppDelegate.scheduleBLERefreshTask()
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var isLandscape = false
    @State private var expandedDate: Date? = nil
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // 現在セッション + 過去ログを一つのScrollViewで表示
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // --- 現在セッションヘッダー ---
                            currentSessionHeader
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            
                            if viewModel.sensorReadings.isEmpty {
                                emptyStateView
                                    .padding(.bottom, 8)
                            } else {
                                LazyVStack(spacing: isLandscape ? 3 : 6) {
                                    ForEach(viewModel.sensorReadings) { reading in
                                        SensorReadingView(
                                            sensorData: reading,
                                            isHighlighted: viewModel.highlightedReadingIds.contains(reading.id),
                                            isLandscapeCompact: isLandscape || isIPad
                                        )
                                        .padding(.horizontal, 8)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // --- 過去ログセクション ---
                            pastLogSectionHeader
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            
                            if viewModel.availableLogDates.isEmpty {
                                Text("ログファイルなし")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                LazyVStack(spacing: 4) {
                                    ForEach(viewModel.availableLogDates, id: \.self) { date in
                                        dateSection(for: date)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                // Data received indicator
                if viewModel.showDataReceivedIndicator {
                    VStack {
                        HStack {
                            Spacer()
                            DataReceivedIndicator()
                                .padding(.trailing, 60)
                        }
                        .padding(.top, -35)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("センサー履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusIndicator(viewModel: viewModel, isCompact: true)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
        .alert("Bluetoothアクセスが拒否されました", isPresented: $viewModel.showBluetoothUnauthorizedAlert) {
            Button("設定を開く") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このアプリがセンサーデータを受信するためには、Bluetoothアクセスを許可してください。\n\n設定 > アプリ > 温度センサー表示 > Bluetooth で設定できます。")
        }
    }
    
    // 現在セッションヘッダー
    private var currentSessionHeader: some View {
        HStack {
            Label("現在のセッション", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundColor(.secondary)
            if !viewModel.sensorReadings.isEmpty {
                Text("(\(viewModel.sensorReadings.count)件)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !viewModel.sensorReadings.isEmpty {
                Button("クリア") {
                    viewModel.clearReadings()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    // 過去ログセクションヘッダー
    private var pastLogSectionHeader: some View {
        HStack {
            Label("過去ログ", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundColor(.secondary)
            if !viewModel.availableLogDates.isEmpty {
                Text("(\(viewModel.availableLogDates.count)日分)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    // 日付ごとの折りたたみセクション
    @ViewBuilder
    private func dateSection(for date: Date) -> some View {
        VStack(spacing: 4) {
            // 日付行（タップで展開/折りたたみ）
            Button(action: { toggleDate(date) }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(formattedLogDate(date))
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    if viewModel.isLoadingDate && isSameDay(viewModel.loadedDate, date) {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: expandedDate.map { isSameDay($0, date) } == true
                              ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                )
            }
            .buttonStyle(.plain)

            // 展開時のデータ一覧
            if expandedDate.map({ isSameDay($0, date) }) == true
                && !viewModel.isLoadingDate {
                if viewModel.selectedDateReadings.isEmpty {
                    Text("データなし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    LazyVStack(spacing: isLandscape ? 3 : 6) {
                        ForEach(viewModel.selectedDateReadings) { reading in
                            SensorReadingView(
                                sensorData: reading,
                                isHighlighted: false,
                                isLandscapeCompact: isLandscape || isIPad
                            )
                            .opacity(0.8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func toggleDate(_ date: Date) {
        if let current = expandedDate, isSameDay(current, date) {
            expandedDate = nil
        } else {
            expandedDate = date
            viewModel.loadReadings(for: date)
        }
    }

    private func isSameDay(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("デバイスを検索中...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !viewModel.isScanning && viewModel.bluetoothState == .poweredOn {
                Button("スキャン開始") {
                    viewModel.startScanning()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 20)
    }
    
    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = orientation.isLandscape
        }
    }
}

#Preview {
    ContentView()
}
