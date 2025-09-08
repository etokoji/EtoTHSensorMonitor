import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var showDataReceivedIndicator = false
    
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
            
            VStack(spacing: 40) {
                // Header
                VStack {
                    Text("ESP32センサー")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let data = latestSensorData {
                        Text("最終更新: \(formattedTimestamp(data.timestamp))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("データ待機中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let data = latestSensorData {
                    // Main sensor data display
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
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
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
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct SensorCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
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

#Preview {
    HomeView(viewModel: SensorViewModel())
}
