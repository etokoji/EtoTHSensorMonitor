import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var showDataReceivedIndicator = false
    @State private var isLandscape = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: isLandscape && !isIPad ? 20 : 40) {
                // Header - smaller in landscape
                VStack(spacing: isLandscape && !isIPad ? 5 : 10) {
                    Text("温度センサー表示")
                        .font(isLandscape && !isIPad ? .title : .largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // 通信状態インジケーター
                    ConnectionStatusIndicator(viewModel: viewModel)
                    
                    if let data = latestSensorData {
                        Text("最終更新: \(formattedTimestamp(data.timestamp))")
                            .font(isLandscape && !isIPad ? .caption : .subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("データ待機中...")
                            .font(isLandscape && !isIPad ? .caption : .subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let data = latestSensorData {
                    // Main sensor data display - adaptive layout
                    if isLandscape || isIPad {
                        // Landscape or iPad: 2x2 grid
                        VStack(spacing: isIPad ? 30 : (isLandscape ? 10 : 20)) {
                            HStack(spacing: isIPad ? 30 : (isLandscape ? 12 : 20)) {
                                SensorCard(
                                    title: "温度",
                                    value: data.formattedTemperature,
                                    icon: "thermometer",
                                    color: .red,
                                    isCompact: !isIPad
                                )
                                
                                SensorCard(
                                    title: "湿度",
                                    value: data.formattedHumidity,
                                    icon: "humidity",
                                    color: .blue,
                                    isCompact: !isIPad
                                )
                            }
                            
                            HStack(spacing: isIPad ? 30 : (isLandscape ? 12 : 20)) {
                                SensorCard(
                                    title: "気圧",
                                    value: data.formattedPressure,
                                    icon: "barometer",
                                    color: .orange,
                                    isCompact: !isIPad
                                )
                                
                                SensorCard(
                                    title: "電圧",
                                    value: data.formattedVoltage,
                                    icon: "battery.100",
                                    color: .green,
                                    isCompact: !isIPad
                                )
                            }
                        }
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
                        Image(systemName: "sensors")
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
                
                if !isLandscape {
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isLandscape && !isIPad ? 10 : 20)
            .padding(.vertical, isLandscape && !isIPad ? 0 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .center : .top)
            
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
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
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
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientation()
        }
        .onReceive(viewModel.dataReceivedSubject) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showDataReceivedIndicator = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDataReceivedIndicator = false
                }
            }
        }
    }
    
    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = orientation.isLandscape
        }
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            )
        } else {
            // Full layout for portrait view
            HStack(spacing: 20) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
    }
}

#Preview {
    HomeView(viewModel: SensorViewModel())
}
