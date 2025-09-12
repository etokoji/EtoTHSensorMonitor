import SwiftUI
import CoreBluetooth

struct WiFiSettingsView: View {
    @StateObject private var wifiConfigService = WiFiConfigService()
    @State private var selectedDevice: WiFiConfigDevice? = nil
    @State private var ssid = ""
    @State private var password = ""
    @State private var showingBackgroundProcessingAlert = false
    
    // メインアプリのCompositeDataServiceへの参照（必須）
    let compositeDataService: CompositeDataService
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. ステータス表示
            statusHeader
            
            // 2. メインコンテンツ
            mainContent
        }
        .navigationTitle("WiFi設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                scanButton
            }
        }
        .onAppear {
            print("[WiFiSettingsView] 画面表示 - スキャン開始")
            print("[WiFiSettingsView] 現在の状態: \(wifiConfigService.state)")
            print("[WiFiSettingsView] スキャン中: \(wifiConfigService.isScanning)")
            wifiConfigService.startScanning()
        }
        .onDisappear {
            print("[WiFiSettingsView] 画面非表示 - WiFi設定処理を中断してTCP接続を再開")
            
            // WiFi設定処理を完全に停止
            wifiConfigService.stopScanning()
            wifiConfigService.disconnect()
            
            // 本来のTCPサーバへの接続を再開
            compositeDataService.forceReconnectTCP()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusHeader: some View {
        VStack(spacing: 4) {
            Text("セットアップ手順")
                .font(.headline)
                .padding(.top)
            
            Text(statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if wifiConfigService.isScanning {
                ProgressView()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom)
        .background(Color(.secondarySystemBackground))
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch wifiConfigService.state {
        case .disconnected, .scanning, .failed:
            deviceList
        case .connecting(let device):
            ConnectingView(deviceName: device.name)
        case .connected:
            credentialInputView
        case .sendingCredentials, .waitingForStatus:
            ProgressView("設定を適用中...")
        case .completed(_, let ipAddress):
            CompletionView(ipAddress: ipAddress) {
                resetToInitialState()
            }
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        if wifiConfigService.discoveredDevices.isEmpty && !wifiConfigService.isScanning {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("デバイスが見つかりません")
                    .font(.headline)
                    .foregroundColor(.gray)
                Button("スキャンを再実行") {
                    wifiConfigService.startScanning()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else {
            List(wifiConfigService.discoveredDevices) { device in
                Button(action: { wifiConfigService.connect(to: device) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("RSSI: \(device.rssi)").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.primary)
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    @ViewBuilder
    private var credentialInputView: some View {
        Form {
            Section(header: Text("WiFi認証情報")) {
                TextField("SSID", text: $ssid)
                SecureField("パスワード", text: $password)
            }
            
            Section {
                Button(action: { wifiConfigService.sendCredentials(ssid: ssid, password: password) }) {
                    HStack {
                        Spacer()
                        Text("設定を送信")
                        Spacer()
                    }
                }
                .disabled(ssid.isEmpty)
            }
            
            Section {
                 Button(action: { wifiConfigService.disconnect() }) {
                    HStack {
                        Spacer()
                        Text("切断")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
    }

    private var scanButton: some View {
        Button(action: {
            print("[WiFiSettingsView] 手動スキャン開始")
            wifiConfigService.startScanning()
        }) {
            Image(systemName: wifiConfigService.isScanning ? "stop.circle" : "arrow.clockwise")
        }
    }

    // MARK: - Helper Functions
    
    private func resetToInitialState() {
        print("[WiFiSettingsView] WiFi設定完了後のリセット - TCP接続を再開")
        
        // WiFi設定サービスをリセット
        wifiConfigService.resetToInitialState()
        
        // UIの入力フィールドをクリア
        ssid = ""
        password = ""
        selectedDevice = nil
        
        // 本来のTCPサーバへの接続を再開
        compositeDataService.forceReconnectTCP()
        
        // 少し待ってからスキャンを再開始（必要な場合）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            wifiConfigService.startScanning()
        }
    }
    
    // MARK: - Helper Properties
    
    private var statusDescription: String {
        switch wifiConfigService.state {
        case .disconnected:
            return "1. 下のリストから設定したいデバイスを選択してください。"
        case .scanning:
            return "付近のデバイスを検索中...しばらくお待ちください"
        case .connecting(let device):
            return "\(device.name)に接続しています..."
        case .connected:
            return "2. WiFiのSSIDとパスワードを入力して送信してください。"
        case .sendingCredentials:
            return "認証情報を送信しています..."
        case .waitingForStatus:
            return "デバイスからの応答を待っています..."
        case .completed(let device, let ipAddress):
            return "\(device.name)のWiFi設定が完了しました！(IP: \(ipAddress))"
        case .failed(let error):
            return "エラー: \(error)\n右上の更新ボタンをタップして再試行してください。"
        }
    }
}

struct ConnectingView: View {
    let deviceName: String
    var body: some View {
        VStack {
            ProgressView("\(deviceName)に接続中...")
        }
    }
}

struct CompletionView: View {
    let ipAddress: String
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("設定完了")
                .font(.largeTitle)
            Text("デバイスのIPアドレスは \(ipAddress) です")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("新しいデバイスを設定する") {
                onReset()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }
}

struct WiFiSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WiFiSettingsView(compositeDataService: CompositeDataService())
    }
}
