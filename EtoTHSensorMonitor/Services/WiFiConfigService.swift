import Foundation
import CoreBluetooth
import Combine

@MainActor
class WiFiConfigService: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var state: WiFiSetupGuide.State = .disconnected
    @Published var discoveredDevices: [WiFiConfigDevice] = []
    @Published var isScanning: Bool = false

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var statusCharacteristic: CBCharacteristic?
    private var credentialsCharacteristic: CBCharacteristic?

    // For chunked data transmission
    private var dataToSend: Data?
    private var dataOffset: Int = 0
    
    private var scanTimer: Timer?
    private let scanTimeout: TimeInterval = 15.0

    // MARK: - Initialization
    override init() {
        super.init()
        print("[WiFiSetup] WiFiConfigServiceを初期化中...")
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        print("[WiFiSetup] CBCentralManagerを作成しました - 初期状態: \(centralManager.state)")
    }

    // MARK: - Public API

    func startScanning() {
        print("[WiFiSetup] startScanning()が呼び出されました")
        print("[WiFiSetup] CBCentralManager状態: \(centralManager.state.rawValue) (\(centralManager.state))")
        
        guard centralManager.state == .poweredOn else {
            if centralManager.state.rawValue == 0 { // unknown状態
                print("[WiFiSetup] Bluetooth状態がまだ初期化中です。有効になるまで待機します...")
                // 状態を失敗にしないで、Bluetoothが有効になったら自動でスキャンされる
                return
            }
            
            let errorMsg = "Bluetoothが有効ではありません - 状態: \(centralManager.state)"
            print("[WiFiSetup] エラー: \(errorMsg)")
            state = .failed(error: errorMsg)
            return
        }

        print("[WiFiSetup] スキャン開始...")
        discoveredDevices.removeAll()
        isScanning = true
        state = .scanning

        centralManager.scanForPeripherals(withServices: nil, options: nil)

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
                if self?.discoveredDevices.isEmpty ?? true {
                    self?.state = .failed(error: "デバイスが見つかりませんでした")
                }
            }
        }
    }

    func stopScanning() {
        print("[WiFiSetup] スキャン停止")
        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        if case .scanning = state {
            state = .disconnected
        }
    }

    func connect(to device: WiFiConfigDevice) {
        print("[WiFiSetup] \(device.name) に接続中...")
        stopScanning()
        state = .connecting(device: device)
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        print("[WiFiSetup] 切断処理開始")
        if let peripheral = connectedPeripheral {
            print("[WiFiSetup] BLE接続を切断中...")
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            print("[WiFiSetup] 接続済みペリフェラルなし - クリーンアップのみ実行")
            cleanup()
            state = .disconnected
        }
    }

    func resetToInitialState() {
        print("[WiFiSetup] サービス状態をリセット")
        // 既存の接続を切断
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // スキャンを停止
        stopScanning()
        
        // 状態をクリア
        cleanup()
        
        // 初期状態に戻す
        state = .disconnected
    }
    
    func sendCredentials(ssid: String, password: String) {
        guard credentialsCharacteristic != nil else {
            state = .failed(error: "書き込み用のキャラクタリスティックが見つかりません")
            return
        }

        let credentials = WiFiSetupGuide.Credentials(ssid: ssid, password: password)
        guard let data = try? JSONEncoder().encode(credentials) else {
            state = .failed(error: "認証情報のエンコードに失敗しました")
            return
        }

        print("[WiFiSetup] 認証情報を送信: \(String(data: data, encoding: .utf8) ?? "") (size: \(data.count) bytes)")
        state = .sendingCredentials
        
        self.dataToSend = data
        self.dataOffset = 0
        
        sendNextChunk()
    }
    
    // MARK: - Private Helper Methods

    private func sendNextChunk() {
        guard let peripheral = connectedPeripheral,
              let characteristic = credentialsCharacteristic,
              let data = dataToSend else {
            return
        }
        
        guard dataOffset < data.count else {
            print("[WiFiSetup] 全データ送信完了 (\(data.count) bytes)")
            self.dataToSend = nil
            self.dataOffset = 0
            Task { @MainActor in
                if let currentDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
                     state = .waitingForStatus(device: currentDevice)
                }
            }
            return
        }
        
        // BLEのMTUを強制的に20バイトに制限して確実にチャンク分割する
        let chunkSize = 20
        
        let end = min(dataOffset + chunkSize, data.count)
        let chunk = data[dataOffset..<end]
        
        let chunkNumber = (dataOffset / chunkSize) + 1
        let totalChunks = (data.count + chunkSize - 1) / chunkSize
        let chunkString = String(data: chunk, encoding: .utf8) ?? "<binary data>"
        print("[WiFiSetup] チャンク送信中... Chunk \(chunkNumber)/\(totalChunks), Offset: \(dataOffset), Size: \(chunk.count) bytes")
        print("[WiFiSetup] チャンク内容: '\(chunkString)'")
        self.dataOffset = end
        peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
    }

    private func cleanup() {
        connectedPeripheral = nil
        statusCharacteristic = nil
        credentialsCharacteristic = nil
        dataToSend = nil
        dataOffset = 0
        // completed状態でもリセットされるように修正
        // これにresetToInitialState()から呼ばれた時はステートを保持
    }
}

// MARK: - CBCentralManagerDelegate
extension WiFiConfigService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[WiFiSetup] CBCentralManager状態が更新されました: \(central.state.rawValue) (\(central.state))")
        
        switch central.state {
        case .poweredOn:
            print("[WiFiSetup] Bluetoothが有効になりました")
            // 状態がdisconnectedである場合、自動的にスキャンを開始
            if case .disconnected = state {
                print("[WiFiSetup] Bluetoothが有効になったのでスキャンを自動開始")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.startScanning()
                }
            }
        case .poweredOff:
            print("[WiFiSetup] Bluetoothが無効です")
            Task { @MainActor in
                state = .failed(error: "Bluetoothが無効です")
            }
        case .unauthorized:
            print("[WiFiSetup] Bluetoothの使用が許可されていません")
            Task { @MainActor in
                state = .failed(error: "Bluetoothの使用が許可されていません")
            }
        case .unsupported:
            print("[WiFiSetup] このデバイスはBluetoothをサポートしていません")
            Task { @MainActor in
                state = .failed(error: "Bluetoothがサポートされていません")
            }
        case .unknown:
            print("[WiFiSetup] Bluetoothの状態が不明です")
        default:
            print("[WiFiSetup] 未知のBluetooth状態: \(central.state)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? ""
        guard !deviceName.isEmpty else { return }
        
        print("[WiFiSetup] 発見: \(deviceName) RSSI: \(RSSI.intValue)")

        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
                let device = WiFiConfigDevice(id: peripheral.identifier, name: deviceName, rssi: RSSI.intValue, peripheral: peripheral)
                discoveredDevices.append(device)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[WiFiSetup] 接続成功: \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([WiFiSetupGuide.UUIDs.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            state = .failed(error: "接続に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
            cleanup()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[WiFiSetup] 切断されました")
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension WiFiConfigService: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == WiFiSetupGuide.UUIDs.serviceUUID {
                peripheral.discoverCharacteristics([
                    WiFiSetupGuide.UUIDs.credentialsCharacteristicUUID,
                    WiFiSetupGuide.UUIDs.statusCharacteristicUUID
                ], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case WiFiSetupGuide.UUIDs.credentialsCharacteristicUUID:
                credentialsCharacteristic = characteristic
            case WiFiSetupGuide.UUIDs.statusCharacteristicUUID:
                statusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        Task { @MainActor in
            if let currentDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
                state = .connected(device: currentDevice)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, characteristic.uuid == WiFiSetupGuide.UUIDs.statusCharacteristicUUID else { return }

        let statusString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let status = try? JSONDecoder().decode(WiFiSetupGuide.StatusNotification.self, from: data) {
            print("[WiFiSetup] Status Update (JSON): \(status)")
            handleStatusUpdate(status: status.status, ipAddress: status.ipAddress, peripheral: peripheral)
        } else if let statusString = statusString, !statusString.isEmpty {
            print("[WiFiSetup] Status Update (String): \(statusString)")
            handleStatusUpdate(status: statusString, ipAddress: nil, peripheral: peripheral)
        } else {
            print("[WiFiSetup] 不明なステータスデータ: \(data.hexDescription)")
        }
    }
    
    private func handleStatusUpdate(status: String, ipAddress: String?, peripheral: CBPeripheral) {
        if status.hasPrefix("received:") {
            // 受信バイト数を抽出
            let receivedBytesStr = String(status.dropFirst("received:".count).dropLast("bytes".count))
            let receivedBytes = Int(receivedBytesStr) ?? 0
            print("[WiFiSetup] ESP32から受信通知: \(status) (受信バイト数: \(receivedBytes)) - 次のチャンクを送信します")
            
            // 現在送信中のデータがあるか確認
            if let data = dataToSend {
                let currentOffset = dataOffset
                print("[WiFiSetup] 現在の送信状況: 全体\(data.count)バイト中\(currentOffset)バイト送信済み")
            }
            
            sendNextChunk()
            return
        }

        Task { @MainActor in
            if let currentDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
                switch status {
                case "connected":
                    state = .completed(device: currentDevice, ipAddress: ipAddress ?? "N/A")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { 
                        Task { @MainActor in
                            self.disconnect() 
                        }
                    }
                case "connecting", "waiting":
                    state = .waitingForStatus(device: currentDevice)
                default:
                    state = .failed(error: "接続失敗: \(status)")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Task { @MainActor in
                state = .failed(error: "書き込み失敗: \(error.localizedDescription)")
                self.dataToSend = nil
                self.dataOffset = 0
            }
            return
        }

        if characteristic.uuid == WiFiSetupGuide.UUIDs.credentialsCharacteristicUUID {
             // 何もしない。didUpdateValueForからの通知をトリガーとする
             print("[WiFiSetup] チャンク書き込み要求完了。ESP32からの通知を待機します。")
        }
    }
}

extension Data {
    var hexDescription: String {
        return reduce("") { $0 + String(format: "%02x", $1) }
    }
}

