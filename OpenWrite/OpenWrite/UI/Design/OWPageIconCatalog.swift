import SwiftUI

/// Page icon tokens — unicode glyphs or the OpenWrite brand mark on the document hero.
enum OWPageIconCatalog {
    /// Stored in `VaultDocument.pageIcon` to render `OpenWriteLogo` in the page chip.
    static let brandLogoToken = "openwrite-logo"

    static func showsBrandLogo(_ icon: String) -> Bool {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == brandLogoToken { return true }
        // Legacy welcome default before brand asset wiring.
        return trimmed == "◎"
    }
}

struct OWPageIconView: View {
    let icon: String
    var size: CGFloat = OWPageBannerMetrics.iconSize

    var body: some View {
        Group {
            if OWPageIconCatalog.showsBrandLogo(icon) {
                OWBrandLogoView(size: size * 0.7)
            } else {
                Text(icon)
                    .font(.system(size: max(18, size * 0.52)))
            }
        }
        .frame(width: size, height: size)
    }
}
