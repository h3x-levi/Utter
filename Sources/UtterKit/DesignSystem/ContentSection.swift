import SwiftUI

/// A content section with a clear heading and accessory, without a decorative card.
///
/// Pages use the window surface as one continuous reading plane. Native lists,
/// separators, grouped Forms, and SF Symbols carry hierarchy; this component
/// contributes only spacing and a consistent section heading.
struct ContentSection<Content: View>: View {
    let title: String?
    var systemImage: String?
    var tint: Color?
    var accessory: AnyView?
    @ViewBuilder let content: () -> Content
    init(
        title: String? = nil,
        systemImage: String? = nil,
        tint: Color? = nil,
        accessory: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            if title != nil || accessory != nil || systemImage != nil {
                header
            }
            content()
        }
        .padding(.vertical, Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: Space.x2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(tint ?? Ink.secondary)
            }
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
            }
            Spacer(minLength: 0)
            if let accessory { accessory }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

