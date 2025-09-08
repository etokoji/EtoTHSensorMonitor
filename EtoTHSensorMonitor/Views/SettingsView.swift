import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
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
    SettingsView()
}
