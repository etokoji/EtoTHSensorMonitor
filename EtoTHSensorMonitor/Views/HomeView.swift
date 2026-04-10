import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var isLandscape = false
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false  // macOSではiPad判定なし（画面幅で大画面判定）
        #endif
    }
    
    // 動的に画面サイズに基づいて大画面かどうかを判定
    private func isLargeScreen(width: CGFloat) -> Bool {
        return isIPad || width > 800
    }
    
    // 動的に画面サイズに基づいてコンパクトデバイスかどうかを判定
    private func isCompactDevice(width: CGFloat) -> Bool {
        // iPad miniや小さなiPad
        if isIPad && width < 900 {
            return true
        }
        // Mac上でのiPadアプリ実行時（画面幅が中程度の場合）
        if width > 500 && width < 1000 {
            return true
        }
        return false
    }
    
    private var latestSensorData: SensorData? {
        // 履歴データから最新を取得（重複も含む）
        if let latest = viewModel.sensorReadings.first {
            return latest
        }
        // 履歴が空の場合はdiscoveredDevicesから取得
        return viewModel.discoveredDevices.values.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    var body: some View {
        // Background gradient with dynamic sizing
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let isLargeScreenDynamic = isLargeScreen(width: screenWidth)
            let isCompactDeviceDynamic = isCompactDevice(width: screenWidth)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: isCompactDeviceDynamic ? 20 : (isLargeScreenDynamic ? 30 : (isLandscape ? 20 : 40))) {
                    // Header - コンパクトデバイスではよりコンパクトに
                    VStack(spacing: isCompactDeviceDynamic ? 5 : (isLargeScreenDynamic ? 8 : (isLandscape ? 5 : 10))) {
                        Text("温度センサー表示")
                            .font(isCompactDeviceDynamic ? .title2 : (isLargeScreenDynamic ? .title : (isLandscape ? .title : .largeTitle)))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // 通信状態インジケーター
                        ConnectionStatusIndicator(viewModel: viewModel)
                        
                        if let data = latestSensorData {
                            Text("最終更新: \(formattedTimestamp(data.timestamp))")
                                .font(isCompactDeviceDynamic ? .caption : (isLargeScreenDynamic ? .footnote : (isLandscape ? .caption : .subheadline)))
                                .foregroundColor(.secondary)
                        } else {
                            Text("データ待機中...")
                                .font(isCompactDeviceDynamic ? .caption : (isLargeScreenDynamic ? .footnote : (isLandscape ? .caption : .subheadline)))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let data = latestSensorData {
                        // Main sensor data display - adaptive layout
                        if isLandscape || isLargeScreenDynamic || isCompactDeviceDynamic {
                            // Landscape, large screen, or compact device: 2x2 grid with maximum width
                            VStack(spacing: isCompactDeviceDynamic ? 15 : (isLargeScreenDynamic ? 25 : (isLandscape ? 10 : 20))) {
                                HStack(spacing: isCompactDeviceDynamic ? 15 : (isLargeScreenDynamic ? 25 : (isLandscape ? 12 : 20))) {
                                    SensorCard(
                                        title: "温度",
                                        value: data.formattedTemperature,
                                        icon: "thermometer",
                                        color: .red,
                                        isCompact: false,
                                        isLargeScreen: isLargeScreenDynamic,
                                        isCompactDevice: isCompactDeviceDynamic
                                    )
                                    
                                    SensorCard(
                                        title: "湿度",
                                        value: data.formattedHumidity,
                                        icon: "humidity",
                                        color: .blue,
                                        isCompact: false,
                                        isLargeScreen: isLargeScreenDynamic,
                                        isCompactDevice: isCompactDeviceDynamic
                                    )
                                }
                                
                                HStack(spacing: isCompactDeviceDynamic ? 15 : (isLargeScreenDynamic ? 25 : (isLandscape ? 12 : 20))) {
                                    SensorCard(
                                        title: "気圧",
                                        value: data.formattedPressure,
                                        icon: "barometer",
                                        color: .orange,
                                        isCompact: false,
                                        isLargeScreen: isLargeScreenDynamic,
                                        isCompactDevice: isCompactDeviceDynamic
                                    )
                                    
                                    SensorCard(
                                        title: "電圧",
                                        value: data.formattedVoltage,
                                        icon: "battery.100",
                                        color: .green,
                                        isCompact: false,
                                        isLargeScreen: isLargeScreenDynamic,
                                        isCompactDevice: isCompactDeviceDynamic
                                    )
                                }
                            }
                            // 最大幅制限を削除し、ウィンドウ幅に比例してカードが拡がる
                        } else {
                            // Portrait: vertical stack
                            VStack(spacing: 30) {
                                SensorCard(
                                    title: "温度",
                                    value: data.formattedTemperature,
                                    icon: "thermometer",
                                    color: .red
                                )
                                
                                SensorCard(
                                    title: "湿度",
                                    value: data.formattedHumidity,
                                    icon: "humidity",
                                    color: .blue
                                )
                                
                                SensorCard(
                                    title: "気圧",
                                    value: data.formattedPressure,
                                    icon: "barometer",
                                    color: .orange
                                )
                                
                                SensorCard(
                                    title: "電圧",
                                    value: data.formattedVoltage,
                                    icon: "battery.100",
                                    color: .green
                                )
                            }
                        }
                    } else {
                        // No data state
                        VStack(spacing: 20) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("センサーデータを検索中...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("ESP32デバイスの電源を入れてください")
                                .font(.body)
                                .foregroundColor(Color.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }
                    
                    if !isLandscape && !isLargeScreenDynamic {
                        Spacer()
                    }
                }
                .padding(.horizontal, max(20, screenWidth * 0.05)) // ウィンドウ幅の5%、最低20ptの動的パディング
                .padding(.top, isCompactDeviceDynamic ? 10 : (isLargeScreenDynamic ? 30 : (isLandscape ? 10 : 20)))
                .padding(.vertical, isCompactDeviceDynamic ? 10 : (isLargeScreenDynamic ? 30 : (isLandscape ? 0 : 20)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: (isLandscape || isLargeScreenDynamic || isCompactDeviceDynamic) ? .center : .top)
            )
        }
        .navigationTitle("ホーム")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // デバッグ情報を表示
            print("🏠 HomeView appeared - scanning status: \(viewModel.isScanning)")
            
            // スキャンが開始されていない場合は開始（フォールバック）
            if !viewModel.isScanning {
                print("⚠️ Scanning not active, starting from HomeView")
                viewModel.startScanning()
            }
            
            // 初期化時に向きをチェック
            updateOrientation()
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
        #endif
        .alert("Bluetoothアクセスが拒否されました", isPresented: $viewModel.showBluetoothUnauthorizedAlert) {
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
    }
    
    private func updateOrientation() {
        #if os(iOS)
        let orientation = UIDevice.current.orientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = orientation.isLandscape
        }
        #endif
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current // 現在のタイムゾーンを使用
        return formatter.string(from: date)
    }
}

struct SensorCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isCompact: Bool = false
    var isLargeScreen: Bool = false
    var isCompactDevice: Bool = false
    
    private var cardBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        if isCompact {
            // Compact layout for landscape/grid view - horizontal like portrait but smaller
            HStack(spacing: 15) {
                // Icon - smaller than portrait
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 45, height: 45)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            )
        } else {
            // Full layout for portrait view and large screens
            HStack(spacing: isCompactDevice ? 15 : 20) {
                // Icon - コンパクトデバイスでは少し大きく
                Image(systemName: icon)
                    .font(.system(size: isCompactDevice ? 35 : 30))
                    .foregroundColor(color)
                    .frame(width: isCompactDevice ? 70 : 60, height: isCompactDevice ? 70 : 60)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: isCompactDevice ? 8 : 5) {
                    Text(title)
                        .font(isCompactDevice ? .title3 : .headline)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: isCompactDevice ? 38 : (isLargeScreen ? 44 : 40), weight: .bold, design: .rounded)) // 大画面で一番大きく、次にiPhone、コンパクトデバイス
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6) // Macでの表示を改善するために縮小率を上げる
                        .allowsTightening(true) // 文字間隔の締めを許可
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: isCompactDevice ? 100 : 80) // コンパクトデバイスではカードを大きく
            .padding(.horizontal, isCompactDevice ? 18 : 15) // コンパクトデバイスでは少し大きなパディング
            .padding(.vertical, isCompactDevice ? 18 : 15)
            .background(
                RoundedRectangle(cornerRadius: isCompactDevice ? 18 : 15)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: isCompactDevice ? 6 : 5, x: 0, y: 2)
            )
        }
    }
}

// プレビュー用のモックViewModelを作成する拡張
extension SensorViewModel {
    static func createMockViewModel() -> SensorViewModel {
        let viewModel = SensorViewModel()
        // 実際のプレビューではデータなしの状態で表示される
        // （SensorDataのイニシャライザーにアクセスできないため）
        return viewModel
    }
}

#Preview("iPad mini - Portrait") {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
}

#Preview("iPad mini - Landscape", traits: .landscapeLeft) {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
}

#Preview("iPhone - Portrait") {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
}

#Preview("iPad Pro - Portrait") {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
}

#Preview("Mac - Compact Size") {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
        .frame(width: 700, height: 500)
}

#Preview("Mac - Large Size") {
    HomeView(viewModel: SensorViewModel.createMockViewModel())
        .frame(width: 1200, height: 800)
}

#Preview("Dynamic Size Demo") {
    GeometryReader { geometry in
        VStack {
            Text("Width: \(Int(geometry.size.width))pt")
                .font(.caption)
                .padding(.bottom, 5)
            HomeView(viewModel: SensorViewModel.createMockViewModel())
        }
    }
    .frame(width: 800, height: 600)
}

#Preview("Size Comparison") {
    ScrollView(.horizontal) {
        HStack(spacing: 20) {
            // iPhone size
            VStack {
                Text("iPhone")
                    .font(.caption)
                HomeView(viewModel: SensorViewModel.createMockViewModel())
                    .frame(width: 390, height: 600)
                    .border(Color.gray, width: 1)
            }
            
            // iPad mini size
            VStack {
                Text("iPad mini")
                    .font(.caption)
                HomeView(viewModel: SensorViewModel.createMockViewModel())
                    .frame(width: 744, height: 600)
                    .border(Color.gray, width: 1)
            }
            
            // Mac compact size
            VStack {
                Text("Mac Compact")
                    .font(.caption)
                HomeView(viewModel: SensorViewModel.createMockViewModel())
                    .frame(width: 700, height: 600)
                    .border(Color.gray, width: 1)
            }
            
            // Mac large size
            VStack {
                Text("Mac Large")
                    .font(.caption)
                HomeView(viewModel: SensorViewModel.createMockViewModel())
                    .frame(width: 1000, height: 600)
                    .border(Color.gray, width: 1)
            }
        }
        .padding()
    }
}
