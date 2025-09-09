import SwiftUI

struct ContentView: View {
    @StateObject private var sharedViewModel = SensorViewModel()
    @State private var showingSettings = false
    
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
            
            RealtimeScanView(viewModel: sharedViewModel)
                .tabItem {
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    Text("リアルタイム")
                }
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: sharedViewModel)
        }
        .onAppear {
            // アプリ起動時にグローバルにスキャンを開始
            print("🚀 App started - initializing bluetooth scanning")
            sharedViewModel.startScanning()
        }
    }
}

struct RealtimeScanView: View {
    @ObservedObject var viewModel: SensorViewModel
    @State private var showDataReceivedIndicator = false
    
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
            .navigationTitle("リアルタイムスキャン")
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
            print("📶 RealtimeScanView appeared - scanning status: \(viewModel.isScanning)")
            
            // フォールバックとしてスキャンが開始されていない場合のみ開始
            if !viewModel.isScanning {
                print("⚠️ Scanning not active, starting from RealtimeScanView")
                viewModel.startScanning()
            }
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
            LazyVStack(spacing: 6) {
                ForEach(viewModel.sensorReadings) { reading in
                    SensorReadingView(
                        sensorData: reading,
                        isHighlighted: viewModel.highlightedReadingIds.contains(reading.id)
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
}

#Preview {
    ContentView()
}
