//
//  WiFiConfigModels.swift
//  EtoTHSensorMonitor
//
//  Created by etok on 2024/07/20.
//

import Foundation
import CoreBluetooth

// MARK: - WiFi Setup Guide Models (based on WiFi_Setup_Central_Guide.txt)

struct WiFiSetupGuide {
    struct UUIDs {
        static let serviceUUID = CBUUID(string: "23F29475-478E-477E-8D0B-071DDA5C5C35")
        static let credentialsCharacteristicUUID = CBUUID(string: "7F807FF5-529E-4143-A47B-9C84B132A7EC")
        static let statusCharacteristicUUID = CBUUID(string: "F6A5577F-1111-4161-84FC-64135AAAED6E")
    }

    struct Credentials: Codable {
        let ssid: String
        let password: String
    }

    struct StatusNotification: Decodable {
        let status: String
        let ipAddress: String?

        enum CodingKeys: String, CodingKey {
            case status
            case ipAddress = "ip_address"
        }
    }

    enum State: Equatable {
        case disconnected
        case scanning
        case connecting(device: WiFiConfigDevice)
        case connected(device: WiFiConfigDevice)
        case sendingCredentials
        case waitingForStatus(device: WiFiConfigDevice)
        case completed(device: WiFiConfigDevice, ipAddress: String)
        case failed(error: String)

        static func == (lhs: WiFiSetupGuide.State, rhs: WiFiSetupGuide.State) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.scanning, .scanning):
                return true
            case let (.connecting(l), .connecting(r)):
                return l.id == r.id
            case let (.connected(l), .connected(r)):
                return l.id == r.id
            case (.sendingCredentials, .sendingCredentials):
                return true
            case let (.waitingForStatus(l), .waitingForStatus(r)):
                return l.id == r.id
            case let (.completed(lDevice, lIp), .completed(rDevice, rIp)):
                return lDevice.id == rDevice.id && lIp == rIp
            case let (.failed(lError), .failed(rError)):
                return lError == rError
            default:
                return false
            }
        }

        var description: String {
            switch self {
            case .disconnected: return "未接続"
            case .scanning: return "デバイスを検索中..."
            case .connecting(let device): return "\(device.name)に接続中..."
            case .connected(let device): return "\(device.name)に接続済み。設定を送信してください。"
            case .sendingCredentials: return "認証情報を送信中..."
            case .waitingForStatus: return "デバイスからの応答を待っています..."
            case .completed(_, let ipAddress): return "設定完了 (IP: \(ipAddress))。接続を解除します。"
            case .failed(let error): return "設定失敗: \(error)"
            }
        }
    }
}

struct WiFiConfigDevice: Identifiable {
    let id: UUID
    let name: String
    var rssi: Int
    let peripheral: CBPeripheral
    
    static func == (lhs: WiFiConfigDevice, rhs: WiFiConfigDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

