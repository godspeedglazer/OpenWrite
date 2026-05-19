import AppKit
import SwiftUI

/// Verified web pages fetched for a chat turn (opens in the default browser).
struct WebSourcePillsView: View {
    let sources: [WebSourceReference]
    var compact: Bool = false

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                if !compact {
                    Text("Web")
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: compact ? 4 : 6) {
                        ForEach(sources) { source in
                            pill(source)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pill(_ source: WebSourceReference) -> some View {
        Button {
            NSWorkspace.shared.open(source.url)
        } label: {
            HStack(spacing: 5) {
                OWUnicodeIconView(icon: .wiki, size: compact ? 12 : 14, color: DesignTokens.Color.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.title ?? source.url.host ?? source.url.absoluteString)
                        .font(compact ? OWTypography.captionEmphasis : OWTypography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if source.chunkCount > 1 {
                        Text("×\(source.chunkCount) excerpts")
                            .font(OWTypography.caption2)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(
                DesignTokens.Color.surface.opacity(0.85),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(source.url.absoluteString)
    }
}
