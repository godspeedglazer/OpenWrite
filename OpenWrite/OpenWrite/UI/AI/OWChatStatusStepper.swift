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

    private let railWidth: CGFloat = 14
    private let dotSize: CGFloat = 12
    private let connectorMinHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isLast: index == steps.count - 1)
            }
        }
        .padding(.leading, DesignTokens.Spacing.spacing1)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response progress")
    }

    @ViewBuilder
    private func stepRow(_ step: ChatPipelineStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                stepIndicator(step.status)
                    .frame(width: railWidth, height: railWidth)
                if !isLast {
                    connector(from: step.status)
                        .frame(width: 2)
                        .frame(minHeight: connectorMinHeight)
                        .padding(.top, 2)
                }
            }
            .frame(width: railWidth)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(step.title)
                    .font(OWTypography.caption)
                    .foregroundStyle(labelColor(for: step.status))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if step.status == .active, showsStreamingDots {
                    StepperStreamingDots()
                }
            }
            .padding(.bottom, isLast ? 0 : 6)

            Spacer(minLength: 0)
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
