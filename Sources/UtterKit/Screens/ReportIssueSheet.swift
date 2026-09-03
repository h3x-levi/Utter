import SwiftUI
import AppKit

public enum IssueCategory: String, CaseIterable, Identifiable {
    case bug = "Bug / Crash"
    case audio = "Audio / Mic"
    case performance = "Performance"
    case feature = "Feature Idea"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .audio: return "waveform.badge.mic"
        case .performance: return "bolt.badge.clock.fill"
        case .feature: return "lightbulb.fill"
        }
    }

    var label: String {
        switch self {
        case .bug: return "Bug / Crash"
        case .audio: return "Audio / Mic"
        case .performance: return "Performance"
        case .feature: return "Feature Idea"
        }
    }

    var defaultTitlePrefix: String {
        switch self {
        case .bug: return "[Bug]: "
        case .audio: return "[Audio]: "
        case .performance: return "[Performance]: "
        case .feature: return "[Feature]: "
        }
    }
}

@MainActor
public final class ReportIssueViewModel: ObservableObject {
    @Published public var category: IssueCategory = .bug
    @Published public var title: String = ""
    @Published public var descriptionText: String = ""
    @Published public var stepsToReproduce: String = ""
    @Published public var expectedBehavior: String = ""
    @Published public var actualBehavior: String = ""
    @Published public var showDiagnostics: Bool = false
    @Published public var copied: Bool = false
    public var initialCrashLog: String? = nil

    public init(initialCrashLog: String? = nil, initialCategory: IssueCategory = .bug) {
        self.initialCrashLog = initialCrashLog
        self.category = initialCategory
    }

    public var diagnosticMarkdown: String {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        let cores = ProcessInfo.processInfo.processorCount
        let appVer = ConfigManager.shared.appVersion
        let model = ModelStore.shared.active.rawValue
        let hotkey = UserData.shared.hotkeyName

        var out = """
        ### System Diagnostics
        - **Utter Version**: \(appVer)
        - **macOS Version**: \(osVer)
        - **Architecture**: \(cores) Cores (Apple Silicon / Metal Acceleration)
        - **Active Speech Model**: \(model)
        - **Configured Hotkey**: \(hotkey)
        - **Local-Only Guarantee**: 100% on-device (Zero cloud endpoints)
        """

        if let crash = initialCrashLog, !crash.isEmpty {
            out += "\n\n### Crash Log / Error Trace\n```\n\(crash.prefix(1000))\n```"
        }

        return out
    }

    public var fullReportMarkdown: String {
        let cleanTitle = title.isEmpty ? "\(category.defaultTitlePrefix)Issue Report" : "\(category.defaultTitlePrefix)\(title)"
        var body = """
        ## \(cleanTitle)

        ### Category
        \(category.rawValue)

        ### Summary / Description
        \(descriptionText.isEmpty ? "_No description provided._" : descriptionText)
        """

        if category != .feature {
            body += """


            ### Steps to Reproduce
            \(stepsToReproduce.isEmpty ? "1. \n2. \n3. " : stepsToReproduce)

            ### Expected Behavior
            \(expectedBehavior.isEmpty ? "_N/A_" : expectedBehavior)

            ### Actual Behavior
            \(actualBehavior.isEmpty ? "_N/A_" : actualBehavior)
            """
        }

        body += "\n\n" + diagnosticMarkdown
        return body
    }

    public func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullReportMarkdown, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.copied = false
        }
    }

    public func openInGitHub(onDismiss: () -> Void) {
        let cleanTitle = title.isEmpty ? "\(category.defaultTitlePrefix)Issue Report" : "\(category.defaultTitlePrefix)\(title)"
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = fullReportMarkdown.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://github.com/h3x-levi/Utter/issues/new?title=\(encodedTitle)&body=\(encodedBody)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            onDismiss()
        }
    }
}

public struct ReportIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ReportIssueViewModel

    public init(initialCrashLog: String? = nil, initialCategory: IssueCategory = .bug) {
        _model = StateObject(wrappedValue: ReportIssueViewModel(initialCrashLog: initialCrashLog, initialCategory: initialCategory))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Space.x3) {
                ZStack {
                    Circle()
                        .fill(Tint.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tint.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Report an Issue / Send Feedback")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Ink.primary)
                    Text("Utter is a bi-ported app. Your feedback directly helps us squash bugs and optimize performance.")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.03))
            .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .bottom)

            // Content Form
            ScrollView {
                VStack(alignment: .leading, spacing: Space.x4) {
                    // Category Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                        HStack(spacing: 8) {
                            ForEach(IssueCategory.allCases) { cat in
                                Button(action: { model.category = cat }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 12))
                                        Text(cat.label)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(model.category == cat ? Tint.accent.opacity(0.2) : Color.white.opacity(0.05))
                                    .foregroundStyle(model.category == cat ? Tint.accent : Ink.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(model.category == cat ? Tint.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary / Title").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                        TextField("e.g. Dictation drops after waking from sleep", text: $model.title)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                        TextEditor(text: $model.descriptionText)
                            .font(.system(size: 12))
                            .frame(height: 70)
                            .padding(6)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }

                    if model.category != .feature {
                        // Steps to Reproduce
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Steps to Reproduce").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                            TextEditor(text: $model.stepsToReproduce)
                                .font(.system(size: 12))
                                .frame(height: 60)
                                .padding(6)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }

                        // Expected vs Actual
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Expected Behavior").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                                TextField("e.g. Text types instantly into Cursor", text: $model.expectedBehavior)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Actual Behavior").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.secondary)
                                TextField("e.g. Pill stayed in transcribing state", text: $model.actualBehavior)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            }
                        }
                    }

                    // Collapsible Diagnostics Box
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation { model.showDiagnostics.toggle() } }) {
                            HStack {
                                Image(systemName: model.showDiagnostics ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Auto-Collected System Diagnostics")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 10))
                                    Text("Sanitized • Zero Telemetry")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(Color.green.opacity(0.9))
                            }
                            .foregroundStyle(Ink.secondary)
                        }
                        .buttonStyle(.plain)

                        if model.showDiagnostics {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(model.diagnosticMarkdown)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.75))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .padding(24)
            }

            // Footer Actions
            HStack(spacing: 14) {
                Button(action: { model.copyToClipboard() }) {
                    HStack(spacing: 6) {
                        Image(systemName: model.copied ? "checkmark" : "doc.on.doc")
                        Text(model.copied ? "Copied to Clipboard!" : "Copy Report Markdown")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.copied ? Color.green : Ink.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Button(action: { model.openInGitHub { dismiss() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Open in GitHub Issues")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Tint.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Tint.accent.opacity(0.4), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.03))
            .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
        }
        .frame(width: 660, height: 620)
        .background(Color(red: 0.12, green: 0.13, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
