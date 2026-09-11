import SwiftUI
import AppKit

/// Native Apple macOS System Settings-style grouped section container.
///
/// Implements macOS Sonoma & Sequoia System Settings visual style:
/// inset card container with continuous rounded corners, subtle hairline border,
/// system control background, and optional header and footer captions.
struct AppleSettingsSection<Content: View>: View {
    let title: String?
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                    .padding(.leading, 6)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Line.hairline, lineWidth: Line.width)
            )

            if let footer {
                Text(footer)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
        }
    }
}

/// A standard Apple System Settings row with leading title/subtitle and trailing control.
struct AppleSettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor ?? Tint.accent)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// A standard Apple System Settings toggle row.
struct AppleSettingsToggle: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor ?? Tint.accent)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Indented hairline divider matching macOS System Settings section rows.
struct AppleSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Line.hairline)
            .frame(height: Line.width)
            .padding(.leading, 14)
    }
}
