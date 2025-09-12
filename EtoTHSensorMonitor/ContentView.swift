import SwiftUI

struct ContentView: View {
    @StateObject private var sharedViewModel = SensorViewModel()
    @State private var showingSettings = false
    @State private var isAppActive = true
    
    var body: some View {
        TabView {
            NavigationView {
                HomeView(viewModel: sharedViewModel)
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
        
        // TCP接続が有効であるのに接続していない場合、再接続を試みる
        if sharedViewModel.tcpEnabled && !sharedViewModel.isTCPConnected {
            print("🌐 TCP enabled but not connected, attempting reconnection")
            sharedViewModel.startTCPConnection()
        }
        
        // Bluetoothスキャンが停止している場合、再開してみる
        if !sharedViewModel.isScanning && !sharedViewModel.isTCPConnected {
            print("📶 Bluetooth not scanning and TCP not connected, restarting scan")
            sharedViewModel.startScanning()
        }
    }
    
    private func handleAppEnteredBackground() {
        print("🔄 Handling app entered background")
        // バックグラウンド時の特別な処理が必要な場合はここに追加
        // 現在は特に何もしない（TCPは自動的に管理される）
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var showDataReceivedIndicator = false
    @State private var isLandscape = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 12) {
                    // Status header
                    statusHeader
                    
                    // Sensor reading history
                    if !viewModel.sensorReadings.isEmpty {
                        sensorHistoryView
                    } else {
                        emptyStateView
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Data received indicator
                if showDataReceivedIndicator {
                    VStack {
                        HStack {
                            Spacer()
                            DataReceivedIndicator()
                                .padding(.trailing, 20)
                        }
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
        .onReceive(viewModel.sensorDataSubject) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showDataReceivedIndicator = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDataReceivedIndicator = false
                }
            }
        }
.onAppear {
            // スキャンは既にContentViewで開始されているはず
            print("📶 HistoryView appeared - scanning status: \(viewModel.isScanning)")
            
            // フォールバックとしてスキャンが開始されていない場合のみ開始
            if !viewModel.isScanning {
                print("⚠️ Scanning not active, starting from HistoryView")
                viewModel.startScanning()
            }
            
            // 初期化時に向きをチェック
            updateOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
    }
    
    private var statusHeader: some View {
        HStack {
            // 通信状態インジケーター
            ConnectionStatusIndicator(viewModel: viewModel, isCompact: true)
            
            if !viewModel.sensorReadings.isEmpty {
                Text("履歴: \(viewModel.sensorReadings.count) 件")
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
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    
    private var sensorHistoryView: some View {
        ScrollView {
            // 縦スクロールは共通、ランドスケープではレコードをコンパクト表示
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
            .padding(.vertical, 8)
        }
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
        .padding(.top, 50)
    }
    
    
    private var bluetoothIconName: String {
        switch viewModel.bluetoothState {
        case .poweredOn:
            return "bluetooth"
        case .poweredOff:
            return "bluetooth.slash"
        default:
            return "bluetooth.trianglebadge.exclamationmark"
        }
    }
    
    private var bluetoothIconColor: Color {
        switch viewModel.bluetoothState {
        case .poweredOn:
            return .blue
        case .poweredOff:
            return .gray
        default:
            return .orange
        }
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
