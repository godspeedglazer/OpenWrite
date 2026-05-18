import SwiftUI

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

/// Theme-aware vertical stepper: filled accent dot + connector for completed steps, ring for active, grey for pending.
struct OWChatStatusStepper: View {
    let steps: [ChatPipelineStep]
    /// When true, animated dots appear only on the active **respond** step.
    var showsStreamingDots: Bool = false

    private let railWidth: CGFloat = 16
    private let dotSize: CGFloat = 10
    private let connectorWidth: CGFloat = 2
    private let rowSpacing: CGFloat = 8
    private let connectorSegmentHeight: CGFloat = 12

    private var rowMinHeight: CGFloat {
        max(dotSize + 4, ceil(OWTypography.Scale.captionLineHeight * OWTypography.dynamicScale) + 2)
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
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
                let next = index + 1 < visibleSteps.count ? visibleSteps[index + 1] : nil
                stepRow(step, nextStep: next, isLast: index == visibleSteps.count - 1)
            }
        }
        .padding(.leading, DesignTokens.Spacing.spacing1)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response progress")
    }

    private func stepRow(_ step: ChatPipelineStep, nextStep: ChatPipelineStep?, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                stepIndicator(step.status)
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: railWidth, height: dotSize)

                if !isLast {
                    connector(from: step.status, to: nextStep?.status)
                        .frame(width: connectorWidth, height: connectorSegmentHeight)
                }
            }
            .frame(width: railWidth, alignment: .top)

            stepLabel(step)
                .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .topLeading)
        }
        .frame(minHeight: rowMinHeight + (isLast ? 0 : connectorSegmentHeight), alignment: .top)
    }

    @ViewBuilder
    private func stepLabel(_ step: ChatPipelineStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(step.title)
                .font(OWTypography.caption)
                .foregroundStyle(labelColor(for: step.status))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if step.status == .active, showsStreamingDots, step.id == "respond" {
                StepperStreamingDots()
            }
        }
        .frame(minHeight: rowMinHeight, alignment: .topLeading)
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
        .frame(width: dotSize, height: dotSize)
        .animation(.easeInOut(duration: 0.32), value: status)
    }

    private func connector(from status: ChatPipelineStep.Status, to nextStatus: ChatPipelineStep.Status?) -> some View {
        Rectangle()
            .fill(connectorColor(from: status, to: nextStatus))
            .animation(.easeInOut(duration: 0.38), value: status)
    }

    private func connectorColor(from status: ChatPipelineStep.Status, to nextStatus: ChatPipelineStep.Status?) -> Color {
        if status == .completed {
            return DesignTokens.Color.accent.opacity(0.55)
        }
        if status == .failed || nextStatus == .failed {
            return DesignTokens.Color.warning.opacity(0.35)
        }
        return DesignTokens.Color.borderSubtle
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
