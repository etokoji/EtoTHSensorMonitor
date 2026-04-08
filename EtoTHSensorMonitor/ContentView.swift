import SwiftUI

struct ContentView: View {
    @StateObject private var sharedViewModel = SensorViewModel()
    @State private var showingSettings = false
    @State private var isAppActive = true
    
    var body: some View {
        TabView {
            NavigationView {
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
    @State private var showPastLogs = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
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
                            
                            if showPastLogs {
                                if viewModel.pastLogReadings.isEmpty {
                                    Text("過去ログなし")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    LazyVStack(spacing: isLandscape ? 3 : 6) {
                                        ForEach(viewModel.pastLogReadings) { reading in
                                            SensorReadingView(
                                                sensorData: reading,
                                                isHighlighted: false,
                                                isLandscapeCompact: isLandscape || isIPad
                                            )
                                            .opacity(0.75)
                                            .padding(.horizontal, 8)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
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
            Label("過去ログ（7日分）", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundColor(.secondary)
            if !viewModel.pastLogReadings.isEmpty && viewModel.isPastLogLoaded {
                Text("(\(viewModel.pastLogReadings.count)件)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !viewModel.isPastLogLoaded {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button(action: { withAnimation { showPastLogs.toggle() } }) {
                    Text(showPastLogs ? "閉じる" : "表示")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
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
