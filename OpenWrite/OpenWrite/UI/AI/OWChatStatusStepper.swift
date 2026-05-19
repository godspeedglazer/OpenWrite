import SwiftUI

// MARK: - LM Studio connection pill (chat composer)

/// Compact status pill driven by `OpenWriteAIServices.LMConnectionState` (probe result, not streaming guesses).
struct OWLMConnectionStatusPill: View {
    let state: OpenWriteAIServices.LMConnectionState

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            Circle()
                .fill(style.dot)
                .frame(width: 6, height: 6)
            Text(state.statusPillLabel)
                .font(OWTypography.caption2)
                .foregroundStyle(style.foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, 2)
        .background(style.background, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(style.border, lineWidth: DesignTokens.Layout.borderWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.statusPillLabel)
    }

    private var style: PillStyle {
        switch state.statusPillTone {
        case .ready:
            return PillStyle(
                foreground: DesignTokens.Color.success,
                background: DesignTokens.Color.success.opacity(0.14),
                border: DesignTokens.Color.success.opacity(0.28),
                dot: DesignTokens.Color.success
            )
        case .warning:
            return PillStyle(
                foreground: DesignTokens.Color.warning,
                background: DesignTokens.Color.warning.opacity(0.14),
                border: DesignTokens.Color.warning.opacity(0.30),
                dot: DesignTokens.Color.warning
            )
        case .offline:
            return PillStyle(
                foreground: DesignTokens.Color.danger,
                background: DesignTokens.Color.dangerMuted.opacity(0.55),
                border: DesignTokens.Color.danger.opacity(0.35),
                dot: DesignTokens.Color.danger
            )
        case .pending:
            return PillStyle(
                foreground: DesignTokens.Color.textSecondary,
                background: DesignTokens.Color.surface.opacity(0.9),
                border: DesignTokens.Color.borderHairline,
                dot: DesignTokens.Color.textTertiary
            )
        }
    }

    private struct PillStyle {
        let foreground: Color
        let background: Color
        let border: Color
        let dot: Color
    }
}

/// Vertical pipeline step for vault chat (Manuscripts-style, theme-aware).
struct ChatPipelineStep: Identifiable, Hashable {
    enum Status: Hashable {
        case pending
        case active
        case completed
        case failed
    }

    let id: String
    var title: String
    var status: Status
}

/// Theme-aware vertical stepper. Uses a single ZStack rail per group so dots are visually connected —
/// previous per-row `VStack { dot, connector }` design left ~16pt gap between connector end and next dot.
struct OWChatStatusStepper: View {
    enum Layout {
        /// Chat transcript — single-line labels beside a compact rail.
        case chat
        /// Refine left rail — wider rail, two-line labels, dots under title (avoids divider clip).
        case refineRail
    }

    let steps: [ChatPipelineStep]
    /// When true, animated dots appear on the active step (chat: **respond**; refine: **model**).
    var showsStreamingDots: Bool = false
    var layout: Layout = .chat

    private var railWidth: CGFloat {
        switch layout {
        case .chat: return 26
        case .refineRail: return 30
        }
    }

    private var dotSize: CGFloat { 10 }

    /// Frame larger than stroke so active rings are not clipped by narrow parents.
    private var dotFrameSize: CGFloat {
        layout == .refineRail ? 16 : 14
    }

    private let connectorWidth: CGFloat = 2

    private var rowHeight: CGFloat {
        let captionLine = ceil(OWTypography.Scale.captionLineHeight * OWTypography.dynamicScale)
        switch layout {
        case .chat:
            return max(dotFrameSize + DesignTokens.Spacing.spacing1, captionLine + DesignTokens.Spacing.spacing1)
        case .refineRail:
            return max(dotFrameSize + 4, captionLine * 2 + 16)
        }
    }

    /// Steps that have started or are next up — hides trailing pending rows that only lengthen the rail.
    private var visibleSteps: [ChatPipelineStep] {
        if let connectFailedIndex = steps.firstIndex(where: { $0.id == "connect" && $0.status == .failed }) {
            return Array(steps.prefix(connectFailedIndex + 1))
        }

        var visible: [ChatPipelineStep] = []
        var includedFirstPending = false
        for step in steps {
            switch step.status {
            case .pending:
                if visible.isEmpty || visible.last?.status == .completed || visible.last?.status == .failed {
                    if !includedFirstPending {
                        visible.append(step)
                        includedFirstPending = true
                    }
                }
            case .active, .completed, .failed:
                visible.append(step)
            }
        }
        return visible
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            railColumn
                .frame(width: railWidth)
            labelColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, layout == .refineRail ? DesignTokens.Spacing.spacing2 : DesignTokens.Spacing.spacing2)
        .padding(.trailing, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
        .compositingGroup()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response progress")
    }

    /// Continuous vertical rail with dots overlaid at row centers. Trim top/bottom by half-row so the
    /// line starts/stops at the first/last dot center (no orphan stub above the first step).
    private var railColumn: some View {
        let count = visibleSteps.count
        let totalHeight = rowHeight * CGFloat(max(count, 1))
        return ZStack(alignment: .top) {
            if count > 1 {
                continuousRail(rowCount: count)
                    .frame(width: connectorWidth)
                    .padding(.top, rowHeight / 2)
                    .padding(.bottom, rowHeight / 2)
                    .frame(maxHeight: .infinity)
            }
            VStack(spacing: 0) {
                ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { _, step in
                    ZStack {
                        stepIndicator(step.status)
                    }
                    .frame(width: railWidth, height: rowHeight)
                }
            }
        }
        .frame(width: railWidth, alignment: .top)
        .frame(minHeight: totalHeight, alignment: .top)
    }

    /// Gradient-aware rail: tints completed prefix with accent, remainder with subtle border tone.
    @ViewBuilder
    private func continuousRail(rowCount: Int) -> some View {
        let stops = railGradientStops(rowCount: rowCount)
        LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func railGradientStops(rowCount: Int) -> [Gradient.Stop] {
        guard rowCount > 1 else {
            return [
                Gradient.Stop(color: DesignTokens.Color.borderSubtle, location: 0),
                Gradient.Stop(color: DesignTokens.Color.borderSubtle, location: 1)
            ]
        }
        var stops: [Gradient.Stop] = []
        for (index, step) in visibleSteps.enumerated() {
            let location = CGFloat(index) / CGFloat(rowCount - 1)
            stops.append(Gradient.Stop(color: railColor(for: step.status), location: location))
        }
        return stops
    }

    private func railColor(for status: ChatPipelineStep.Status) -> Color {
        switch status {
        case .completed:
            return DesignTokens.Color.accent.opacity(0.65)
        case .active:
            return DesignTokens.Color.accent.opacity(0.45)
        case .failed:
            return DesignTokens.Color.warning.opacity(0.45)
        case .pending:
            return DesignTokens.Color.borderSubtle
        }
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { _, step in
                stepLabel(step)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: rowHeight, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func stepLabel(_ step: ChatPipelineStep) -> some View {
        let title = Text(step.title)
            .font(OWTypography.caption)
            .foregroundStyle(labelColor(for: step.status))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

        if layout == .refineRail {
            VStack(alignment: .leading, spacing: 3) {
                title
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                if step.status == .active, showsStreamingDots {
                    StepperStreamingDots()
                }
            }
        } else {
            HStack(alignment: .center, spacing: 6) {
                title
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .truncationMode(.tail)
                if step.status == .active, showsStreamingDots {
                    StepperStreamingDots()
                }
            }
        }
    }

    @ViewBuilder
    private func stepIndicator(_ status: ChatPipelineStep.Status) -> some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: 1.5)
                    .background(Circle().fill(DesignTokens.Color.surface))
            case .active:
                Circle()
                    .strokeBorder(DesignTokens.Color.accent, lineWidth: 2)
                    .background(Circle().fill(DesignTokens.Color.background))
            case .completed:
                Circle()
                    .fill(DesignTokens.Color.accent)
            case .failed:
                Circle()
                    .fill(DesignTokens.Color.warning.opacity(0.85))
            }
        }
        .frame(width: dotFrameSize, height: dotFrameSize)
        .animation(.easeInOut(duration: 0.32), value: status)
    }

    private func labelColor(for status: ChatPipelineStep.Status) -> Color {
        switch status {
        case .pending:
            return DesignTokens.Color.textTertiary
        case .active, .completed:
            return DesignTokens.Color.textSecondary
        case .failed:
            return DesignTokens.Color.textSecondary
        }
    }
}

private struct StepperStreamingDots: View {
    @State private var phase = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(DesignTokens.Color.accent.opacity(index == phase ? 1 : 0.35))
                    .frame(width: 5, height: 5)
            }
        }
        .onAppear { startAnimation() }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            phase = 0
        }
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}
