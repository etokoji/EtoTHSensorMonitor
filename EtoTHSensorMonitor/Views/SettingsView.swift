import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @ObservedObject var viewModel: SensorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("接続設定")) {
                    // TCP接続の有効/無効
                    Toggle("TCPサーバ接続", isOn: $viewModel.tcpEnabled)
                    
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
                    
                    if viewModel.tcpEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("サーバ情報")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(settings.serverIPAddress):8080")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("接続状態: \(viewModel.tcpConnectionState)")
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
}

#Preview {
    SettingsView(viewModel: SensorViewModel())
}
