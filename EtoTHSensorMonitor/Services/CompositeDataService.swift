import Foundation
import Combine
import CoreBluetooth

class CompositeDataService: ObservableObject {
    @Published var discoveredDevices: [String: SensorData] = [:]
    @Published var isBluetoothScanning = false
    @Published var isTCPConnected = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var tcpConnectionState: String = "Disconnected"
    @Published var activeConnectionType: String = "None"
    
    // TCP接続の有効/無効を制御（デフォルトでON）
    @Published var tcpEnabled = true {
        didSet {
            if oldValue != tcpEnabled {
                print("🔄 TCP enabled changed: \(oldValue) -> \(tcpEnabled)")
                handleConnectionPriorityChange()
            }
        }
    }
    
    let sensorDataPublisher = PassthroughSubject<SensorData, Never>()
    let dataReceivedPublisher = PassthroughSubject<Void, Never>()
    let allDataPublisher = PassthroughSubject<SensorData, Never>()
    
    private let bluetoothService = BluetoothService()
    private let tcpService = TCPService()
    private var cancellables = Set<AnyCancellable>()
    private var shouldScanBluetooth = false // Bluetoothスキャンの意図を記録
    
    init() {
        setupBindings()
        
        // デフォルトでTCP接続を開始（初期化後に実行）
        DispatchQueue.main.async {
            if self.tcpEnabled && !self.isTCPConnected {
                print("🌐 Initial TCP connection start")
                self.tcpService.startConnection()
            }
        }
    }
    
    private func setupBindings() {
        // Bluetooth bindings
        bluetoothService.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.isBluetoothScanning = isScanning
                self?.updateActiveConnectionType()
            }
            .store(in: &cancellables)
        
        bluetoothService.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bluetoothState = state
            }
            .store(in: &cancellables)
        
        bluetoothService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bluetoothDevices in
                // TCP接続中でない場合のみBluetoothデータを使用
                if self?.isTCPConnected != true {
                    self?.discoveredDevices = bluetoothDevices
                }
            }
            .store(in: &cancellables)
        
        // TCP bindings
        tcpService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                let wasConnected = self?.isTCPConnected ?? false
                self?.isTCPConnected = isConnected
                
                // TCP接続状態が変化した時の処理
                if isConnected && !wasConnected {
                    // TCP接続成功時: Bluetoothを停止
                    self?.bluetoothService.stopScanning()
                    self?.discoveredDevices.removeAll() // Bluetoothデータをクリア
                    print("🔄 TCP connected, stopping Bluetooth scanning")
                } else if !isConnected && wasConnected {
                    // TCP切断時: 必要に応じてBluetoothを再開
                    if self?.shouldScanBluetooth == true {
                        self?.bluetoothService.startScanning()
                        print("🔄 TCP disconnected, resuming Bluetooth scanning")
                    }
                    self?.discoveredDevices.removeAll() // TCPデータをクリア
                }
                
                self?.updateActiveConnectionType()
            }
            .store(in: &cancellables)
        
        tcpService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.tcpConnectionState = state
                self?.updateActiveConnectionType()
            }
            .store(in: &cancellables)
        
        tcpService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tcpDevices in
                // TCP接続中の場合のみTCPデータを使用
                if self?.isTCPConnected == true {
                    self?.discoveredDevices = tcpDevices
                }
            }
            .store(in: &cancellables)
        
        // Data publishers - 現在アクティブな接続からのデータのみ転送
        bluetoothService.sensorDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                if self?.isTCPConnected != true { // TCP非接続時のみBluetooth データを転送
                    self?.sensorDataPublisher.send(sensorData)
                }
            }
            .store(in: &cancellables)
        
        bluetoothService.dataReceivedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.isTCPConnected != true {
                    self?.dataReceivedPublisher.send()
                }
            }
            .store(in: &cancellables)
        
        bluetoothService.allDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                if self?.isTCPConnected != true {
                    self?.allDataPublisher.send(sensorData)
                }
            }
            .store(in: &cancellables)
        
        tcpService.sensorDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                if self?.isTCPConnected == true { // TCP接続時のみTCPデータを転送
                    self?.sensorDataPublisher.send(sensorData)
                }
            }
            .store(in: &cancellables)
        
        tcpService.dataReceivedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.isTCPConnected == true {
                    self?.dataReceivedPublisher.send()
                }
            }
            .store(in: &cancellables)
        
        tcpService.allDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                if self?.isTCPConnected == true {
                    self?.allDataPublisher.send(sensorData)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectionPriorityChange() {
        print("🔄 handleConnectionPriorityChange: tcpEnabled=\(tcpEnabled), isTCPConnected=\(isTCPConnected)")
        
        if tcpEnabled {
            // TCPが有効で、まだ接続していない場合のみ接続開始
            if !isTCPConnected {
                tcpService.startConnection()
            }
        } else {
            // TCPを無効にする
            tcpService.stopConnection()
            // TCP無効時、Bluetoothが必要なら開始
            if shouldScanBluetooth && !isBluetoothScanning {
                bluetoothService.startScanning()
            }
        }
    }
    
    private func updateActiveConnectionType() {
        if isTCPConnected {
            activeConnectionType = "TCP"
        } else if isBluetoothScanning {
            activeConnectionType = "Bluetooth"
        } else {
            activeConnectionType = "None"
        }
    }
    
    // MARK: - Public Methods
    
    func startBluetoothScanning() {
        shouldScanBluetooth = true
        // TCP接続中でない場合のみ実際にスキャンを開始
        if !isTCPConnected {
            bluetoothService.startScanning()
        } else {
            print("🔄 Bluetooth scan requested but TCP is connected - will start when TCP disconnects")
        }
    }
    
    func stopBluetoothScanning() {
        shouldScanBluetooth = false
        bluetoothService.stopScanning()
    }
    
    func toggleBluetoothScanning() {
        if shouldScanBluetooth {
            stopBluetoothScanning()
        } else {
            startBluetoothScanning()
        }
    }
    
    func startTCPConnection() {
        tcpEnabled = true
    }
    
    func stopTCPConnection() {
        tcpEnabled = false
    }
    
    func toggleTCPConnection() {
        tcpEnabled.toggle()
    }
    
    /// バックグラウンド移行時の処理
    func handleEnterBackground() {
        bluetoothService.handleEnterBackground()
        print("🔄 CompositeDataService: entered background")
    }
    
    /// フォアグラウンド復帰時の処理
    func handleEnterForeground() {
        bluetoothService.handleEnterForeground()
        print("🔄 CompositeDataService: entered foreground")
    }
    
    /// WiFi設定完了後のTCP再接続用
    func forceReconnectTCP() {
        print("🌐 Force TCP reconnection after WiFi setup")
        
        // tcpEnabledの状態変更を使用して確実に再接続をトリガー
        if tcpEnabled {
            // 一度無効にして有効に戻すことで、handleConnectionPriorityChange()を確実に呼び出す
            tcpEnabled = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tcpEnabled = true
            }
        } else {
            // 既に無効な場合は有効にする
            tcpEnabled = true
        }
    }
    
    // MARK: - Computed Properties
    
    var hasReadings: Bool {
        !discoveredDevices.isEmpty
    }
    
    var bluetoothStateDescription: String {
        switch bluetoothState {
        case .poweredOn:
            return "接続可能"
        case .poweredOff:
            return "オフ"
        case .unauthorized:
            return "未許可"
        case .unsupported:
            return "非サポート"
        case .resetting:
            return "リセット中"
        default:
            return "不明"
        }
    }
    
    var connectionStatusText: String {
        if tcpEnabled {
            if isTCPConnected {
                return "TCP: 接続中"
            } else {
                return "TCP: \(localizedTCPConnectionState)"
            }
        } else if isBluetoothScanning {
            return "BLE: スキャン中"
        } else {
            return "未接続"
        }
    }
    
    private var localizedTCPConnectionState: String {
        switch tcpConnectionState {
        case "Connected":
            return "接続中"
        case "Disconnected":
            return "未接続"
        case "Waiting":
            return "接続待機中"
        case "Failed":
            return "接続失敗"
        case "Cancelled":
            return "キャンセル済み"
        default:
            return tcpConnectionState
        }
    }
    
    var detailedConnectionStatus: String {
        var status: [String] = []
        
        if shouldScanBluetooth {
            if isTCPConnected {
                status.append("BLE: 待機中 (TCP優先)")
            } else {
                status.append("BLE: \(isBluetoothScanning ? "スキャン中" : "停止")")
            }
        } else {
            status.append("BLE: 無効")
        }
        
        if tcpEnabled {
            status.append("TCP: \(tcpConnectionState)")
        } else {
            status.append("TCP: 無効")
        }
        
        return status.joined(separator: " | ")
    }
    
    var connectionStatusColor: String {
        if tcpEnabled && isTCPConnected {
            return "green"
        } else if tcpEnabled && !isTCPConnected {
            return "orange"
        } else if isBluetoothScanning {
            return "blue"
        } else {
            return "gray"
        }
    }
}
