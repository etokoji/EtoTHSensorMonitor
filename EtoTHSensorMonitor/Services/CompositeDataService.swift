import Foundation
import Combine
import CoreBluetooth

class CompositeDataService: ObservableObject {
    @Published var discoveredDevices: [String: SensorData] = [:]
    @Published var isBluetoothScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    
    let sensorDataPublisher = PassthroughSubject<SensorData, Never>()
    let dataReceivedPublisher = PassthroughSubject<Void, Never>()
    let allDataPublisher = PassthroughSubject<SensorData, Never>()
    
    private let bluetoothService = BluetoothService()
    private var cancellables = Set<AnyCancellable>()
    private var shouldScanBluetooth = false // Bluetoothスキャンの意図を記録
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        bluetoothService.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.isBluetoothScanning = isScanning
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
                self?.discoveredDevices = bluetoothDevices
            }
            .store(in: &cancellables)
        
        bluetoothService.sensorDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.sensorDataPublisher.send(sensorData)
            }
            .store(in: &cancellables)
        
        bluetoothService.dataReceivedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dataReceivedPublisher.send()
            }
            .store(in: &cancellables)
        
        bluetoothService.allDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensorData in
                self?.allDataPublisher.send(sensorData)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startBluetoothScanning() {
        shouldScanBluetooth = true
        bluetoothService.startScanning()
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
        if isBluetoothScanning {
            return "BLE: スキャン中"
        } else {
            return "未接続"
        }
    }
    
    var detailedConnectionStatus: String {
        if shouldScanBluetooth {
            return "BLE: \(isBluetoothScanning ? "スキャン中" : "停止")"
        } else {
            return "BLE: 無効"
        }
    }
    
    var connectionStatusColor: String {
        if isBluetoothScanning {
            return "blue"
        } else {
            return "gray"
        }
    }
}
