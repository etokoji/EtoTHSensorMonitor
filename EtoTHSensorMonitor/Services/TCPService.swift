import Foundation
import Network
import Combine

class TCPService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: String = "Disconnected"
    @Published var discoveredDevices: [String: SensorData] = [:]
    
    private var connection: NWConnection?
    private let port: UInt16 = 8080
    private let queue = DispatchQueue(label: "TCPService")
    
    // 保存されたサーバーIPを取得
    private var serverHost: String {
        return SettingsManager.shared.serverIPAddress
    }
    
    // 自動再接続のための変数
    private var shouldAutoReconnect = true
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 5
    private var baseReconnectDelay: TimeInterval = 2.0
    
    let sensorDataPublisher = PassthroughSubject<SensorData, Never>()
    let dataReceivedPublisher = PassthroughSubject<Void, Never>()
    let allDataPublisher = PassthroughSubject<SensorData, Never>()
    
    override init() {
        super.init()
    }
    
    func startConnection() {
        // 既に接続しているか、接続中の場合は何もしない
        if let existingConnection = connection {
            switch existingConnection.state {
            case .ready:
                print("🌐 TCP already connected")
                return
            case .preparing, .waiting:
                print("🌐 TCP connection in progress")
                return
            default:
                // 失敗やキャンセル状態の場合は再接続を許可
                connection?.cancel()
                connection = nil
            }
        }
        
        // 手動で開始された場合、再接続試行回数をリセット
        shouldAutoReconnect = true
        reconnectAttempts = 0
        
        let currentHost = serverHost
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(currentHost), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateChange(state)
            }
        }
        
        connection?.start(queue: queue)
        print("🌐 Starting TCP connection to \(currentHost):\(port)")
    }
    
    func stopConnection() {
        shouldAutoReconnect = false
        reconnectAttempts = 0
        connection?.cancel()
        connection = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = "Disconnected"
        }
        
        print("🌐 TCP connection stopped")
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnected = true
            connectionState = "Connected"
            reconnectAttempts = 0  // 接続成功時はリセット
            print("🌐 TCP connection established")
            receiveData()
            
        case .waiting(let error):
            isConnected = false
            connectionState = "Waiting"
            print("🌐 TCP connection waiting: \(error)")
            
        case .failed(let error):
            isConnected = false
            connectionState = "Failed"
            print("🌐 TCP connection failed: \(error)")
            
            // 自動再接続を試みる（制限あり）
            if shouldAutoReconnect && reconnectAttempts < maxReconnectAttempts {
                scheduleReconnection()
            } else if reconnectAttempts >= maxReconnectAttempts {
                print("🌐 Max reconnection attempts reached, stopping auto-reconnect")
                shouldAutoReconnect = false
            }
            
        case .cancelled:
            isConnected = false
            connectionState = "Cancelled"
            print("🌐 TCP connection cancelled")
            
        default:
            connectionState = "Unknown"
            print("🌐 TCP connection state: \(state)")
        }
    }
    
    private func reconnect() {
        guard !isConnected else { return }
        
        print("🌐 Attempting to reconnect TCP...")
        connection?.cancel()
        connection = nil
        startConnection()
    }
    
    private func scheduleReconnection() {
        reconnectAttempts += 1
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        let maxDelay: TimeInterval = 30.0
        let actualDelay = min(delay, maxDelay)
        
        print("🌐 Scheduling reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(actualDelay)s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + actualDelay) { [weak self] in
            guard let self = self,
                  self.shouldAutoReconnect,
                  !self.isConnected else {
                print("🌐 Reconnection cancelled or already connected")
                return
            }
            
            self.reconnect()
        }
    }
    
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("🌐 TCP receive error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processReceivedData(data)
            }
            
            if isComplete {
                print("🌐 TCP connection completed")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionState = "Completed"
                }
                return
            }
            
            // Continue receiving
            self?.receiveData()
        }
    }
    
    private func processReceivedData(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            print("🌐 Failed to convert data to string")
            return
        }
        
        // Handle multiple JSON objects that might be concatenated
        let jsonLines = jsonString.components(separatedBy: .newlines)
        
        for line in jsonLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            parseJSONLine(trimmedLine)
        }
    }
    
    private func parseJSONLine(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("🌐 Failed to convert JSON string to data")
            return
        }
        
        do {
            let tcpSensorData = try JSONDecoder().decode(TCPSensorData.self, from: jsonData)
            let deviceAddress = "TCP_\(tcpSensorData.dev_id)"
            
            let sensorData = tcpSensorData.toSensorData(
                deviceAddress: deviceAddress,
                deviceName: "TCP Sensor \(tcpSensorData.dev_id)"
                // TCP接続ではRSSI値は意味を持たないためnilを使用
            )
            
            DispatchQueue.main.async {
                // 最新のタイムスタンプで更新
                self.discoveredDevices[deviceAddress] = sensorData
                
                // すべての通知を送信
                self.dataReceivedPublisher.send()
                self.allDataPublisher.send(sensorData)
                self.sensorDataPublisher.send(sensorData)
            }
            
            print("🌐 TCP Data - Device: \(tcpSensorData.dev_id), Temp: \(tcpSensorData.temperature_C)°C, Humidity: \(tcpSensorData.humidity_pct)%, Pressure: \(tcpSensorData.pressure_hPa)hPa, Voltage: \(tcpSensorData.voltage_V)V")
            
        } catch {
            print("🌐 Failed to parse JSON: \(error)")
            print("🌐 JSON string: \(jsonString)")
        }
    }
}
