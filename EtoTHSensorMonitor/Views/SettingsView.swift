import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @ObservedObject var viewModel: SensorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingIPAddress = false
    @State private var tempIPAddress = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("接続設定")) {
                    // TCP接続の有効/無効
                    Toggle("TCPサーバ接続", isOn: $viewModel.tcpEnabled)
                    
                    // TCPサーバIPアドレス設定
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TCPサーバIPアドレス")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if isEditingIPAddress {
                            // 編集モード
                            HStack {
                                TextField("192.168.1.89", text: $tempIPAddress)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled(true)
                                
                                if isValidIPAddress(tempIPAddress) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else if !tempIPAddress.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                            
                            HStack {
                                Button("接続") {
                                    // IPアドレスを保存して接続
                                    settings.serverIPAddress = tempIPAddress
                                    isEditingIPAddress = false
                                    
                                    // TCP接続を再試行
                                    if viewModel.tcpEnabled {
                                        viewModel.reconnectTCP()
                                    }
                                }
                                .buttonStyle(BorderedProminentButtonStyle())
                                .disabled(!isValidIPAddress(tempIPAddress))
                                
                                Button("キャンセル") {
                                    tempIPAddress = settings.serverIPAddress
                                    isEditingIPAddress = false
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        } else {
                            // 表示モード
                            HStack {
                                Text(settings.serverIPAddress.isEmpty ? "未設定" : settings.serverIPAddress)
                                    .foregroundColor(settings.serverIPAddress.isEmpty ? .secondary : .primary)
                                
                                Spacer()
                                
                                if isValidIPAddress(settings.serverIPAddress) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else if !settings.serverIPAddress.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                                
                                Button("変更") {
                                    tempIPAddress = settings.serverIPAddress
                                    isEditingIPAddress = true
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                        
                        Text("ポート番号は8080で固定です")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // WiFi設定画面へのナビゲーション
                    NavigationLink(destination: WiFiSettingsView(compositeDataService: viewModel.dataService)) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            Text("WiFi設定")
                            Spacer()
                        }
                    }
                    
                    // 接続状態表示
                    VStack(alignment: .leading, spacing: 4) {
                        Text("接続状態")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.detailedConnectionStatus)
                            .font(.footnote)
                            .foregroundColor(
                                viewModel.activeConnectionType == "TCP" ? .green :
                                viewModel.activeConnectionType == "Bluetooth" ? .blue : .secondary
                            )
                    }
                    
                    // TCP接続状態表示
                    if viewModel.tcpEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TCP接続状態")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.tcpConnectionState)")
                                .font(.footnote)
                                .foregroundColor(
                                    viewModel.isTCPConnected ? .green : .orange
                                )
                        }
                    }
                    
                    // WiFi接続情報表示
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WiFi接続情報")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("SSID:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(settings.wifiSSID)
                                .font(.footnote)
                                .foregroundColor(settings.wifiSSID == "未設定" ? .orange : .primary)
                        }
                        HStack {
                            Text("サーバIP:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(settings.serverIPAddress)
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section(header: Text("電池設定")) {
                    // 電池タイプ選択
                    Picker("電池タイプ", selection: $settings.selectedBatteryType) {
                        ForEach(BatteryType.allCases, id: \.self) { batteryType in
                            Text(batteryType.displayName).tag(batteryType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // 通知の有効/無効
                    Toggle("電池残量通知", isOn: $settings.batteryNotificationsEnabled)
                }
                
                if settings.batteryNotificationsEnabled {
                    Section(header: Text("電圧閾値"), footer: Text(voltageFooterText)) {
                        // 危険電圧
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("危険電圧")
                                    .foregroundColor(.red)
                                Spacer()
                                Text("\(settings.criticalVoltageThreshold, specifier: "%.2f")V")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $settings.criticalVoltageThreshold, 
                                   in: 2.0...4.0, 
                                   step: 0.05)
                                .accentColor(.red)
                        }
                        
                        // 警告電圧
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("警告電圧")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(settings.lowVoltageThreshold, specifier: "%.2f")V")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $settings.lowVoltageThreshold, 
                                   in: settings.criticalVoltageThreshold + 0.05...4.2, 
                                   step: 0.05)
                                .accentColor(.orange)
                        }
                        
                        // プリセット値に戻すボタン
                        if settings.selectedBatteryType != .custom {
                            Button("プリセット値に戻す") {
                                settings.criticalVoltageThreshold = settings.selectedBatteryType.defaultCriticalVoltage
                                settings.lowVoltageThreshold = settings.selectedBatteryType.defaultLowVoltage
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Section(header: Text("通知設定")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("通知間隔")
                                Spacer()
                                Text(formatCooldownPeriod(settings.notificationCooldownPeriod))
                                    .foregroundColor(.secondary)
                            }
                            
                            Picker("通知間隔", selection: $settings.notificationCooldownPeriod) {
                                Text("15分").tag(900.0)
                                Text("30分").tag(1800.0)
                                Text("1時間").tag(3600.0)
                                Text("2時間").tag(7200.0)
                                Text("6時間").tag(21600.0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                
                Section(header: Text("その他")) {
                    Button("すべての設定をリセット") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
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
    
    private var voltageFooterText: String {
        let batteryType = settings.selectedBatteryType
        if batteryType == .custom {
            return "カスタム電圧設定です。お使いの電池に合わせて調整してください。"
        } else {
            return "\\(batteryType.displayName) の標準的な電圧範囲に基づいています。"
        }
    }
    
    private func formatCooldownPeriod(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)分"
        } else {
            return "\(minutes / 60)時間"
        }
    }
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else { return false }
        
        for component in components {
            guard let number = Int(component),
                  number >= 0 && number <= 255 else {
                return false
            }
        }
        return true
    }
}

#Preview {
    SettingsView(viewModel: SensorViewModel())
}
