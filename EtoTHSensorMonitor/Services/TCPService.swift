import Foundation
import Network
import Combine

class TCPService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: String = "Disconnected"
    @Published var discoveredDevices: [String: SensorData] = [:]
    
    private var connection: NWConnection?
    private let host = "192.168.1.89"
    private let port: UInt16 = 8080
    private let queue = DispatchQueue(label: "TCPService")
    
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
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateChange(state)
            }
        }
        
        connection?.start(queue: queue)
        print("🌐 Starting TCP connection to \(host):\(port)")
    }
    
    func stopConnection() {
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
            
            // 再接続は手動で行うか、必要に応じて実装
            // 自動再接続は現在無効化
            
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
                deviceName: "TCP Sensor \(tcpSensorData.dev_id)",
                rssi: -30 // TCP接続なので良好な信号強度として設定
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
