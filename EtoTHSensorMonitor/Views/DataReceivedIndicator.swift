import SwiftUI

struct DataReceivedIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Pulsing circle
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.7 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("受信")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VStack {
        DataReceivedIndicator()
        
        Spacer().frame(height: 50)
        
        // Preview with background
        ZStack {
            Color.gray.opacity(0.1)
                .frame(width: 300, height: 200)
            
            VStack {
                HStack {
                    Spacer()
                    DataReceivedIndicator()
                        .padding(.trailing, 20)
                }
                Spacer()
            }
        }
    }
    .padding()
}
