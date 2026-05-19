import SwiftUI

/// Unified OpenWrite mark (`openwritelogo` asset) — used on splash and future loading states.
struct OWBrandLogoView: View {
    var size: CGFloat = 56
    var rotationDegrees: Double = 0

    var body: some View {
        brandImage
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotationDegrees))
            .accessibilityLabel("OpenWrite")
    }

    @ViewBuilder
    private var brandImage: some View {
        if NSImage(named: "OpenWriteLogo") != nil {
            Image("OpenWriteLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else if NSImage(named: "OpenWriteMark") != nil {
            Image("OpenWriteMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "circle.hexagongrid.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(DesignTokens.Color.accent, DesignTokens.Color.accentMuted)
        }
    }
}

/// Continuous rotation for loading (replaces pinwheels). Call `start()` from `onAppear`.
struct OWBrandLogoSpinner: View {
    var size: CGFloat = 28
    var periodSeconds: Double = 1.4

    @State private var rotation: Double = 0

    var body: some View {
        OWBrandLogoView(size: size, rotationDegrees: rotation)
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: periodSeconds).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
