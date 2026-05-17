import SwiftUI

// MARK: - Version gate

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

/// Full-window launch overlay, then crossfade into the main shell (once per app version).
struct LaunchRootView<Main: View>: View {
    @AppStorage(LaunchIntroStorage.lastSeenVersionKey) private var lastSeenIntroVersion = ""
    @State private var showIntroOverlay = false
    @State private var mainShellOpacity: Double = 1

    @ViewBuilder private let main: () -> Main

    init(@ViewBuilder main: @escaping () -> Main) {
        self.main = main
    }

    var body: some View {
        ZStack {
            main()
                .opacity(mainShellOpacity)

            if showIntroOverlay {
                LaunchIntroView(
                    onCrossfade: {
                        withAnimation(.easeInOut(duration: LaunchIntroTiming.crossfade)) {
                            mainShellOpacity = 1
                        }
                    },
                    onFinished: finishIntro
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear(perform: configureLaunchPresentation)
    }

    private func configureLaunchPresentation() {
        guard LaunchIntroStorage.shouldShowIntro(lastSeenVersion: lastSeenIntroVersion) else {
            mainShellOpacity = 1
            showIntroOverlay = false
            return
        }
        mainShellOpacity = 0
        showIntroOverlay = true
    }

    private func finishIntro() {
        lastSeenIntroVersion = LaunchIntroStorage.currentAppVersion
        showIntroOverlay = false
        mainShellOpacity = 1
    }
}

// MARK: - Intro overlay

private enum LaunchIntroTiming {
    static let wordmarkFadeIn: TimeInterval = 0.12
    static let holdBeforeCrossfade: TimeInterval = 0.10
    static let crossfade: TimeInterval = 0.18
}

struct LaunchIntroView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onCrossfade: () -> Void
    let onFinished: () -> Void

    @State private var wordmarkOpacity: Double = 0
    @State private var overlayOpacity: Double = 1
    @State private var introTask: Task<Void, Never>?

    var body: some View {
        let _ = themeManager.selectedTheme
        ZStack {
            themeManager.palette.background
                .ignoresSafeArea()

            Text("OpenWrite")
                .font(OWTypography.documentTitle)
                .tracking(-0.4)
                .foregroundStyle(themeManager.palette.textPrimary)
                .opacity(wordmarkOpacity)
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
            }

            let crossfadeStart = LaunchIntroTiming.wordmarkFadeIn + LaunchIntroTiming.holdBeforeCrossfade
            let crossfadeNanos = UInt64(crossfadeStart * 1_000_000_000)
            try? await Task.sleep(nanoseconds: crossfadeNanos)
            guard !Task.isCancelled else { return }

            onCrossfade()
            withAnimation(.easeInOut(duration: LaunchIntroTiming.crossfade)) {
                overlayOpacity = 0
            }

            let fadeNanos = UInt64(LaunchIntroTiming.crossfade * 1_000_000_000)
            try? await Task.sleep(nanoseconds: fadeNanos)
            guard !Task.isCancelled else { return }

            onFinished()
        }
    }
}

#Preview("Intro overlay") {
    LaunchIntroView(onCrossfade: {}, onFinished: {})
        .environment(ThemeManager.shared)
        .openWritePalette(ThemeManager.shared.palette)
        .frame(width: 900, height: 600)
}
