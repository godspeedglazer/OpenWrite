import SwiftUI

// MARK: - Version gate (optional analytics; splash runs every cold launch)

enum LaunchIntroStorage {
    static let lastSeenVersionKey = "com.openwrite.launchIntro.lastSeenVersion"

    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func shouldShowIntro(lastSeenVersion: String) -> Bool {
        lastSeenVersion != currentAppVersion
    }
}

// MARK: - Root wrapper

/// Brief Anytype-style splash on every launch, then crossfade into the main shell.
struct LaunchRootView<Main: View>: View {
    @AppStorage(LaunchIntroStorage.lastSeenVersionKey) private var lastSeenIntroVersion = ""
    @State private var showIntroOverlay = true
    @State private var mainShellOpacity: Double = 0

    @ViewBuilder private let main: () -> Main

    init(@ViewBuilder main: @escaping () -> Main) {
        self.main = main
    }

    var body: some View {
        ZStack {
            main()
                .opacity(mainShellOpacity)

            if showIntroOverlay {
                LaunchIntroView(onFinished: finishIntro)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear(perform: configureLaunchPresentation)
    }

    private func configureLaunchPresentation() {
        mainShellOpacity = 0
        showIntroOverlay = true
    }

    private func finishIntro() {
        if LaunchIntroStorage.shouldShowIntro(lastSeenVersion: lastSeenIntroVersion) {
            lastSeenIntroVersion = LaunchIntroStorage.currentAppVersion
        }
        showIntroOverlay = false
        withAnimation(.easeOut(duration: LaunchIntroTiming.shellReveal)) {
            mainShellOpacity = 1
        }
    }
}

// MARK: - Intro overlay

private enum LaunchIntroTiming {
    /// Total perceived splash ≈ 0.8s (fade-in + hold + fade-out) before `onFinished`.
    static let wordmarkFadeIn: TimeInterval = 0.20
    static let hold: TimeInterval = 0.30
    static let overlayFadeOut: TimeInterval = 0.30
    static let shellReveal: TimeInterval = 0.24
}

struct LaunchIntroView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onFinished: () -> Void

    @State private var wordmarkOpacity: Double = 0
    @State private var versionOpacity: Double = 0
    @State private var overlayOpacity: Double = 1
    @State private var introTask: Task<Void, Never>?

    private var palette: ThemePalette { themeManager.palette }

    private var appVersion: String {
        LaunchIntroStorage.currentAppVersion
    }

    var body: some View {
        let _ = themeManager.revision
        ZStack {
            palette.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.spacing3) {
                OWBrandLogoSpinner(size: 72, periodSeconds: 2.6)
                    .opacity(wordmarkOpacity)

                Text("OpenWrite")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .textCase(.lowercase)
                    .foregroundStyle(palette.textPrimary)
                    .opacity(wordmarkOpacity)

                Text(themeManager.selectedTheme.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .opacity(versionOpacity)

                Text(themeManager.selectedTheme.shortDescription)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 300)
                    .opacity(versionOpacity)

                Text("v\(appVersion)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.textTertiary)
                    .opacity(versionOpacity)
            }
        }
        .opacity(overlayOpacity)
        .allowsHitTesting(overlayOpacity > 0.01)
        .onAppear(perform: runIntroSequence)
        .onDisappear {
            introTask?.cancel()
            introTask = nil
        }
    }

    private func runIntroSequence() {
        introTask?.cancel()
        introTask = Task { @MainActor in
            withAnimation(.easeOut(duration: LaunchIntroTiming.wordmarkFadeIn)) {
                wordmarkOpacity = 1
                versionOpacity = 1
            }

            let holdStart = LaunchIntroTiming.wordmarkFadeIn + LaunchIntroTiming.hold
            try? await Task.sleep(nanoseconds: UInt64(holdStart * 1_000_000_000))
            guard !Task.isCancelled else {
                onFinished()
                return
            }

            withAnimation(.easeInOut(duration: LaunchIntroTiming.overlayFadeOut)) {
                overlayOpacity = 0
            }

            try? await Task.sleep(nanoseconds: UInt64(LaunchIntroTiming.overlayFadeOut * 1_000_000_000))
            guard !Task.isCancelled else {
                onFinished()
                return
            }

            onFinished()
        }
    }
}

#Preview("Intro overlay") {
    LaunchIntroView(onFinished: {})
        .environment(ThemeManager.shared)
        .frame(width: 900, height: 600)
}
