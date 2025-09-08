import SwiftUI

struct SensorReadingView: View {
    let sensorData: SensorData
    let isHighlighted: Bool
    
    @State private var highlightOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 6) {
            // First line: Device info and timestamp
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ID:\(sensorData.deviceId)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let deviceName = sensorData.deviceName {
                            Text(deviceName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // バックグラウンドインジケーター
                        if sensorData.isFromBackground {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.fill")
                                Text("バックグラウンド")
                            }
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
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
                    HStack(spacing: 2) {
                        rssiIcon
                        Text("\(sensorData.rssi)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        if sensorData.rssi >= Constants.rssiGoodThreshold {
            return "wifi.circle.fill"
        } else if sensorData.rssi >= Constants.rssiFairThreshold {
            return "wifi.circle"
        } else {
            return "wifi.slash"
        }
    }
    
    private var rssiColor: Color {
        if sensorData.rssi >= Constants.rssiGoodThreshold {
            return .green
        } else if sensorData.rssi >= Constants.rssiFairThreshold {
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
    
    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
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
        // 通常状態
        SensorReadingView(
            sensorData: SensorData(
                deviceAddress: "AA:BB:CC:DD:EE:FF",
                deviceName: "ESP32-ENV-01",
                rssi: -55,
                deviceId: 1,
                readingId: 123,
                temperatureCelsius: 23.5,
                humidityPercent: 65.2,
                pressureHPa: 1013.2, // 標準大気圧 (hPa単位)
                voltageVolts: 3.45,
                groupedCount: 1
            ),
            isHighlighted: false
        )
        
        // グループ化されたデータ（ハイライト状態）
        SensorReadingView(
            sensorData: SensorData(
                deviceAddress: "BB:CC:DD:EE:FF:AA",
                deviceName: "ESP32-ENV-02",
                rssi: -42,
                deviceId: 2,
                readingId: 456,
                temperatureCelsius: 25.8,
                humidityPercent: 58.3,
                pressureHPa: 1025.0, // 高気圧 (hPa単位)
                voltageVolts: 3.67,
                groupedCount: 5  // 5件グループの例
            ),
            isHighlighted: true
        )
    }
    .padding()
}
