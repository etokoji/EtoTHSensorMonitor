import SwiftUI

struct ConnectionStatusIndicator: View {
    @ObservedObject var viewModel: SensorViewModel
    let isCompact: Bool
    
    init(viewModel: SensorViewModel, isCompact: Bool = false) {
        self.viewModel = viewModel
        self.isCompact = isCompact
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 接続状態アイコン
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
            
            if !isCompact {
                // 接続状態テキスト
                Text(viewModel.connectionStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(connectionColor)
            }
            
            // TCP接続中の場合は追加の状態表示
            if viewModel.tcpEnabled && viewModel.isTCPConnected && !isCompact {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 3 : 4)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .fill(connectionColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .stroke(connectionColor, lineWidth: 1)
        )
    }
    
    private var connectionIcon: String {
        if viewModel.tcpEnabled {
            if viewModel.isTCPConnected {
                return "wifi"
            } else {
                return "wifi.slash"
            }
        } else if viewModel.isScanning {
            return "bluetooth"
        } else {
            return "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    private var connectionColor: Color {
        if viewModel.tcpEnabled && viewModel.isTCPConnected {
            return .green
        } else if viewModel.tcpEnabled && !viewModel.isTCPConnected {
            return .orange
        } else if viewModel.isScanning {
            return .blue
        } else {
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionStatusIndicator(viewModel: SensorViewModel(), isCompact: false)
        ConnectionStatusIndicator(viewModel: SensorViewModel(), isCompact: true)
    }
    .padding()
}
