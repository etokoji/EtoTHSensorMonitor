import SwiftUI

struct SensorReadingView: View {
    let sensorData: SensorData
    let isHighlighted: Bool
    var isLandscapeCompact: Bool = false
    
    @State private var highlightOpacity: Double = 0.0
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        Group {
            if isLandscapeCompact {
                // ランドスケープ用: 1行レイアウト
                HStack(spacing: 12) {
                    // デバイスIDと種別
                    HStack(spacing: 4) {
                    Text("ID:\(sensorData.deviceId)")
                        .font(isIPad ? .subheadline : .caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(sensorData.deviceAddress.hasPrefix("TCP_") ? "TCP" : "BLE")
                        .font(isIPad ? .subheadline : .caption2)
                        .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    }
                    
                // 時刻
                Text(sensorData.formattedTimestamp)
                    .font(isIPad ? .subheadline : .caption2)
                    .foregroundColor(.secondary)
                    .frame(width: isIPad ? 110 : 70)
                    
                // センサー値を横一列に
                HStack(spacing: isIPad ? 32 : 16) {
                        CompactSensorValue(
                            title: "温",
                            value: sensorData.formattedTemperature,
                            color: temperatureColor
                        )
                        
                        CompactSensorValue(
                            title: "湿",
                            value: sensorData.formattedHumidity,
                            color: humidityColor
                        )
                        
                        CompactSensorValue(
                            title: "気",
                            value: sensorData.formattedPressure,
                            color: pressureColor
                        )
                    }
                    
                    Spacer()
                    
                    // RSSIと電圧
                    HStack(spacing: 8) {
                        // TCP接続時はRSSI表示を省略
                        if let rssi = sensorData.rssi {
                            HStack(spacing: 2) {
                                rssiIcon
                                Text("\(rssi)dBm")
                                    .font(isIPad ? .subheadline : .caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "network")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("TCP")
                                    .font(isIPad ? .subheadline : .caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text(sensorData.formattedVoltage)
                            .font(isIPad ? .subheadline : .caption2)
                            .foregroundColor(voltageColor)
                            .fontWeight(.medium)
                    }
                    
                    // グループ件数
                    if sensorData.groupedCount > 1 {
                        Text("(\(sensorData.groupedCount)件)")
                            .font(isIPad ? .subheadline : .caption2)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, isIPad ? 24 : 12)
                .padding(.vertical, isIPad ? 16 : 6)
            } else {
                // 通常表示: 縦方向レイアウト
                VStack(spacing: 6) {
                    // First line: Device info and timestamp
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("ID:\(sensorData.deviceId)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(sensorData.deviceAddress.hasPrefix("TCP_") ? "TCP" : "BLE")
                                    .font(isIPad ? .caption : .caption2)
                                    .foregroundColor(.secondary)
                                
                                if sensorData.groupedCount > 1 {
                                    Text("(\(sensorData.groupedCount)件)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Text(sensorData.formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // RSSI and Voltage in compact form
                        HStack(spacing: 8) {
                            // TCP接続時はRSSI表示を省略
                            if let rssi = sensorData.rssi {
                                HStack(spacing: 2) {
                                    rssiIcon
                                    Text("\(rssi)dBm")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: "network")
                                        .foregroundColor(.green)
                                        .font(.caption2)
                                    Text("TCP")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            HStack(spacing: 2) {
                                Text(sensorData.formattedVoltage)
                                    .font(.caption2)
                                    .foregroundColor(voltageColor)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    // Second line: Sensor readings in compact horizontal layout
                    HStack(spacing: 16) {
                        CompactSensorValue(
                            title: "温度",
                            value: sensorData.formattedTemperature,
                            color: temperatureColor
                        )
                        
                        CompactSensorValue(
                            title: "湿度",
                            value: sensorData.formattedHumidity,
                            color: humidityColor
                        )
                        
                        CompactSensorValue(
                            title: "気圧",
                            value: sensorData.formattedPressure,
                            color: pressureColor
                        )
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, isIPad ? 16 : 12)
                .padding(.vertical, isIPad ? 12 : 8)
            }
        }
        .background(
            ZStack {
                // 基本背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                
                // アニメーション背景オーバーレイ - 明るい色で目立たせる
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.green.opacity(0.8),
                                Color.yellow.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(highlightOpacity)
            }
        )
        .cornerRadius(8)
        .shadow(
            color: isHighlighted ? Color.blue.opacity(0.3) : Color.black.opacity(0.08),
            radius: isHighlighted ? 6 : 3,
            x: 0,
            y: 1
        )
        .onChange(of: isHighlighted) {
            if isHighlighted {
                // ゆっくりとした背景フェードイン
                withAnimation(.easeIn(duration: 0.5)) {
                    highlightOpacity = 0.8
                }
                // じわっとゆっくりフェードアウト（4秒かけて）
                withAnimation(.easeOut(duration: 4.0).delay(1.0)) {
                    highlightOpacity = 0.0
                }
            } else {
                // 即座にリセット
                withAnimation(.easeOut(duration: 0.3)) {
                    highlightOpacity = 0.0
                }
            }
        }
    }
    
    private var rssiIcon: some View {
        Image(systemName: rssiIconName)
            .foregroundColor(rssiColor)
            .font(.caption)
    }
    
    private var rssiIconName: String {
        guard let rssi = sensorData.rssi else {
            return "network"  // TCP接続用アイコン
        }
        
        if rssi >= Constants.rssiGoodThreshold {
            return "wifi.circle.fill"
        } else if rssi >= Constants.rssiFairThreshold {
            return "wifi.circle"
        } else {
            return "wifi.slash"
        }
    }
    
    private var rssiColor: Color {
        guard let rssi = sensorData.rssi else {
            return .green  // TCP接続は緑色
        }
        
        if rssi >= Constants.rssiGoodThreshold {
            return .green
        } else if rssi >= Constants.rssiFairThreshold {
            return .orange
        } else {
            return .red
        }
    }
    
    private var temperatureColor: Color {
        if sensorData.temperatureCelsius < 18 {
            return .blue
        } else if sensorData.temperatureCelsius > 28 {
            return .red
        } else {
            return .green
        }
    }
    
    private var humidityColor: Color {
        if sensorData.humidityPercent < 40 {
            return .orange
        } else if sensorData.humidityPercent > 70 {
            return .blue
        } else {
            return .green
        }
    }
    
    private var pressureColor: Color {
        let hPa = sensorData.pressureHPa
        if hPa < 1000 {  // 低気圧 (雨の後)
            return .blue
        } else if hPa > 1020 {  // 高気圧 (晴れ)
            return .orange
        } else {
            return .green  // 普通
        }
    }
    
    private var voltageColor: Color {
        if sensorData.voltageVolts < 3.0 {
            return .red
        } else if sensorData.voltageVolts < 3.3 {
            return .orange
        } else {
            return .green
        }
    }
}

struct CompactSensorValue: View {
    let title: String
    let value: String
    let color: Color
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(isIPad ? .subheadline : .caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(isIPad ? .body : .caption)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
    }
}

struct SensorValueView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        // BLEデバイス（RSSIあり）
        SensorReadingView(
            sensorData: SensorData(
                deviceAddress: "AA:BB:CC:DD:EE:FF",
                deviceName: "ESP32-ENV-01",
                rssi: -55,
                deviceId: 1,
                readingId: 123,
                temperatureCelsius: 23.5,
                humidityPercent: 65.2,
                pressureHPa: 1013.2,
                voltageVolts: 3.45,
                groupedCount: 1
            ),
            isHighlighted: false
        )
        
        // TCPデバイス（RSSIなし）
        SensorReadingView(
            sensorData: SensorData(
                deviceAddress: "TCP_2",
                deviceName: "TCP Sensor 2",
                rssi: nil,  // TCP接続なのでnil
                deviceId: 2,
                readingId: 456,
                temperatureCelsius: 25.8,
                humidityPercent: 58.3,
                pressureHPa: 1025.0,
                voltageVolts: 3.67,
                groupedCount: 1
            ),
            isHighlighted: true
        )
    }
    .padding()
}
