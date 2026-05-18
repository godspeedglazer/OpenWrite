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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isLast: index == steps.count - 1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response progress")
    }

    @ViewBuilder
    private func stepRow(_ step: ChatPipelineStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                stepIndicator(step.status)
                if !isLast {
                    connector(from: step.status)
                }
            }
            .frame(width: 14)

            HStack(spacing: 6) {
                Text(step.title)
                    .font(OWTypography.caption)
                    .foregroundStyle(labelColor(for: step.status))
                    .fixedSize(horizontal: false, vertical: true)
                if step.status == .active, showsStreamingDots {
                    StepperStreamingDots()
                }
            }
            .padding(.bottom, isLast ? 0 : 8)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func stepIndicator(_ status: ChatPipelineStep.Status) -> some View {
        switch status {
        case .pending:
            Circle()
                .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: 1.5)
                .background(Circle().fill(DesignTokens.Color.surface))
                .frame(width: 10, height: 10)
        case .active:
            Circle()
                .strokeBorder(DesignTokens.Color.accent, lineWidth: 2)
                .background(Circle().fill(DesignTokens.Color.background))
                .frame(width: 12, height: 12)
        case .completed:
            Circle()
                .fill(DesignTokens.Color.accent)
                .frame(width: 10, height: 10)
        case .failed:
            Circle()
                .fill(DesignTokens.Color.warning)
                .frame(width: 10, height: 10)
        }
    }

  private func connector(from status: ChatPipelineStep.Status) -> some View {
        Rectangle()
            .fill(status == .completed ? DesignTokens.Color.accent.opacity(0.55) : DesignTokens.Color.borderSubtle)
            .frame(width: 2, height: 18)
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
