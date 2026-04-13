import SwiftUI

struct VelaSpinner: View {
    let size: CGFloat
    let lineWidth: CGFloat
    
    init(size: CGFloat = 32, lineWidth: CGFloat = 4) {
        self.size = size
        self.lineWidth = lineWidth
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                Color.velaGradient,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct ProviderBadge: View {
    let providerId: UUID?
    var providerName: String? = nil  // Optionally precomputed by parent
    
    private var displayName: String {
        if let name = providerName, !name.isEmpty { return name }
        // Lightweight fallback — no observation, just a one-time read
        if let id = providerId,
           let provider = PersistenceService.shared.providers.first(where: { $0.id == id }) {
            return provider.name
        }
        if PersistenceService.shared.providers.count == 1,
           let uniqueProvider = PersistenceService.shared.providers.first {
            return uniqueProvider.name
        }
        return "Vela IPTV"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(displayName.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.5)
        }
        .foregroundColor(providerId == nil ? Color.appTextSecondary : Color.appAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                if providerId != nil {
                    Color.appAccent.opacity(0.12)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(providerId == nil ? Color.white.opacity(0.1) : Color.appAccent.opacity(0.3), lineWidth: 0.5)
        )
    }
}
