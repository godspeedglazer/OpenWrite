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
    var showsStreamingDots: Bool = false

    private let railWidth: CGFloat = 16
    private let dotSize: CGFloat = 10
    private let connectorWidth: CGFloat = 2
    private let rowSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                stepRow(step, isLast: index == steps.count - 1)
            }
        }
        .padding(.leading, DesignTokens.Spacing.spacing1)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response progress")
    }

    private func stepRow(_ step: ChatPipelineStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                stepIndicator(step.status)
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: railWidth, height: dotSize)

                if !isLast {
                    connector(from: step.status)
                        .frame(width: connectorWidth)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: connectorMinHeight, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(width: railWidth)

            stepLabel(step)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Minimum rail segment between dots; grows with the label so the connector meets the next dot.
    private var connectorMinHeight: CGFloat {
        max(10, OWTypography.Scale.captionLineHeight * OWTypography.dynamicScale + rowSpacing - dotSize)
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
                .fixedSize(horizontal: false, vertical: true)
            if step.status == .active, showsStreamingDots {
                StepperStreamingDots()
            }
        }
        .frame(minHeight: dotSize, alignment: .leadingFirstTextBaseline)
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
                    .fill(DesignTokens.Color.warning)
            }
        }
        .frame(width: dotSize, height: dotSize)
        .animation(.easeInOut(duration: 0.32), value: status)
    }

    private func connector(from status: ChatPipelineStep.Status) -> some View {
        Rectangle()
            .fill(status == .completed ? DesignTokens.Color.accent.opacity(0.55) : DesignTokens.Color.borderSubtle)
            .animation(.easeInOut(duration: 0.38), value: status)
    }

    private func labelColor(for status: ChatPipelineStep.Status) -> Color {
        switch status {
        case .pending:
            return DesignTokens.Color.textTertiary
        case .active, .completed:
            return DesignTokens.Color.textSecondary
        case .failed:
            return DesignTokens.Color.textPrimary
        }
    }
}

private struct StepperStreamingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(DesignTokens.Color.accent.opacity(index == phase ? 1 : 0.35))
                    .frame(width: 5, height: 5)
            }
        }
        .onAppear {
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(320))
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
