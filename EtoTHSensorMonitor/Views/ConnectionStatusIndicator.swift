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
        if viewModel.isScanning {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    private var connectionColor: Color {
        if viewModel.isScanning {
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
