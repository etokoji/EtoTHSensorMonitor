import Foundation

enum BatteryType: String, CaseIterable {
    case lithiumIon = "lithiumIon"
    case lifePo4 = "lifePo4"           // リン酸鉄リチウムイオン
    case sodiumIon = "sodiumIon"       // ナトリウムイオン
    case custom = "custom"             // カスタム設定
    
    var displayName: String {
        switch self {
        case .lithiumIon:
            return "Li-ion (3.7V)"
        case .lifePo4:
            return "LiFePO4 (3.2V)"
        case .sodiumIon:
            return "Na-ion (3.1V)"
        case .custom:
            return "カスタム設定"
        }
    }
    
    // デフォルトの電圧閾値
    var defaultCriticalVoltage: Double {
        switch self {
        case .lithiumIon:
            return 3.0    // Li-ion: 3.0V以下で危険
        case .lifePo4:
            return 2.8    // LiFePO4: 2.8V以下で危険
        case .sodiumIon:
            return 2.5    // Na-ion: 2.5V以下で危険
        case .custom:
            return 3.0    // デフォルト値
        }
    }
    
    var defaultLowVoltage: Double {
        switch self {
        case .lithiumIon:
            return 3.2    // Li-ion: 3.2V以下で警告
        case .lifePo4:
            return 3.0    // LiFePO4: 3.0V以下で警告
        case .sodiumIon:
            return 2.8    // Na-ion: 2.8V以下で警告
        case .custom:
            return 3.2    // デフォルト値
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var selectedBatteryType: BatteryType {
        didSet {
            UserDefaults.standard.set(selectedBatteryType.rawValue, forKey: "selectedBatteryType")
            // 電池タイプが変更されたときはデフォルト値に戻す（カスタム以外）
            if selectedBatteryType != .custom {
                criticalVoltageThreshold = selectedBatteryType.defaultCriticalVoltage
                lowVoltageThreshold = selectedBatteryType.defaultLowVoltage
            }
        }
    }
    
    @Published var criticalVoltageThreshold: Double {
        didSet {
            UserDefaults.standard.set(criticalVoltageThreshold, forKey: "criticalVoltageThreshold")
        }
    }
    
    @Published var lowVoltageThreshold: Double {
        didSet {
            UserDefaults.standard.set(lowVoltageThreshold, forKey: "lowVoltageThreshold")
        }
    }
    
    @Published var batteryNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(batteryNotificationsEnabled, forKey: "batteryNotificationsEnabled")
        }
    }
    
    // 通知の頻度制限（秒）
    @Published var notificationCooldownPeriod: Double {
        didSet {
            UserDefaults.standard.set(notificationCooldownPeriod, forKey: "notificationCooldownPeriod")
        }
    }
    
    // TCP サーバーIPアドレス
    @Published var serverIPAddress: String {
        didSet {
            UserDefaults.standard.set(serverIPAddress, forKey: "serverIPAddress")
        }
    }
    
    // WiFi SSID
    @Published var wifiSSID: String {
        didSet {
            UserDefaults.standard.set(wifiSSID, forKey: "wifiSSID")
        }
    }
    
    private init() {
        // 保存された値を読み込み、なければデフォルト値を使用
        let savedBatteryType = UserDefaults.standard.string(forKey: "selectedBatteryType") ?? BatteryType.lithiumIon.rawValue
        let batteryType = BatteryType(rawValue: savedBatteryType) ?? .lithiumIon
        self.selectedBatteryType = batteryType
        
        self.criticalVoltageThreshold = UserDefaults.standard.object(forKey: "criticalVoltageThreshold") as? Double ?? batteryType.defaultCriticalVoltage
        self.lowVoltageThreshold = UserDefaults.standard.object(forKey: "lowVoltageThreshold") as? Double ?? batteryType.defaultLowVoltage
        self.batteryNotificationsEnabled = UserDefaults.standard.object(forKey: "batteryNotificationsEnabled") as? Bool ?? true
        self.notificationCooldownPeriod = UserDefaults.standard.object(forKey: "notificationCooldownPeriod") as? Double ?? 3600 // 1時間
        self.serverIPAddress = UserDefaults.standard.string(forKey: "serverIPAddress") ?? "192.168.1.89" // デフォルトIP
        self.wifiSSID = UserDefaults.standard.string(forKey: "wifiSSID") ?? "未設定" // デフォルトSSID
    }
    
    // 設定をデフォルト値にリセット
    func resetToDefaults() {
        selectedBatteryType = .lithiumIon
        criticalVoltageThreshold = selectedBatteryType.defaultCriticalVoltage
        lowVoltageThreshold = selectedBatteryType.defaultLowVoltage
        batteryNotificationsEnabled = true
        notificationCooldownPeriod = 3600
        serverIPAddress = "192.168.1.89"
        wifiSSID = "未設定"
    }
    
    // 電圧レベルを判定
    func getBatteryStatus(voltage: Double) -> BatteryStatus {
        if voltage <= criticalVoltageThreshold {
            return .critical
        } else if voltage <= lowVoltageThreshold {
            return .low
        } else {
            return .normal
        }
    }
}

enum BatteryStatus {
    case normal
    case low
    case critical
    
    var displayText: String {
        switch self {
        case .normal:
            return "正常"
        case .low:
            return "残量少"
        case .critical:
            return "要交換"
        }
    }
    
    var color: String {
        switch self {
        case .normal:
            return "green"
        case .low:
            return "orange"
        case .critical:
            return "red"
        }
    }
}
