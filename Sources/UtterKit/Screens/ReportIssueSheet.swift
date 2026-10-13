import SwiftUI
import AppKit
import UtterCore

public enum IssueCategory: String, CaseIterable, Identifiable {
    case bug = "Bug / Crash"
    case audio = "Audio / Mic"
    case performance = "Performance"
    case feature = "Feature Idea"

    public var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: "Something broke"
        case .audio: "Microphone or sound"
        case .performance: "Slow or stuck"
        case .feature: "An idea"
        }
    }

    var titlePrefix: String {
        switch self {
        case .bug: "[Bug]: "
        case .audio: "[Audio]: "
        case .performance: "[Performance]: "
        case .feature: "[Feature]: "
        }
    }
}

@MainActor @Observable
final class ReportIssueModel {
    var category: IssueCategory
    var title = ""
    var details = ""
    var steps = ""
    var expected = ""
    var actual = ""
    private(set) var copied = false

    let diagnostics: String

    @ObservationIgnored private let close: @MainActor () -> Void

    static let newIssue = "https://github.com/h3x-levi/Utter/issues/new"
    private static let queryValue = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#"))

    init(crashLog: String? = nil,
         category: IssueCategory = .bug,
         appVersion: String = ConfigManager.shared.appVersion,
         speechModel: String? = nil,
         hotkey: String = UserData.shared.hotkeyName,
         device: Device = .current(),
         macOS: String = ProcessInfo.processInfo.operatingSystemVersionString,
         home: String = NSHomeDirectory(),
         close: @escaping @MainActor () -> Void = { NSApp.keyWindow?.performClose(nil) }) {
        self.category = category
        self.close = close
        var lines = """
        ### System Diagnostics
        - **Utter Version**: \(appVersion)
        - **macOS Version**: \(macOS)
        - **Hardware**: \(device.chipName), \(device.totalCores) logical processors, \(device.ramGB) GB memory
        - **Active Speech Model**: \(speechModel ?? ModelStore.shared.active.rawValue)
        - **Configured Hotkey**: \(hotkey)
        - **Processing**: Local Whisper inference; Utter does not upload audio or transcript text
        """
        if let crashLog, !crashLog.isEmpty {
            let sanitized = crashLog.prefix(1000).replacingOccurrences(of: home, with: "~")
            lines += "\n\n### Crash Log\n```\n\(sanitized)\n```"
        }
        diagnostics = lines
    }

    var fullTitle: String {
        category.titlePrefix + (title.isEmpty ? "Issue Report" : title)
    }

    var report: String {
        var body = """
        ## \(fullTitle)

        ### Category
        \(category.rawValue)

        ### Summary / Description
        \(details.isEmpty ? "_No description provided._" : details)
        """
        if category != .feature {
            body += """


            ### Steps to Reproduce
            \(steps.isEmpty ? "1. \n2. \n3. " : steps)

            ### Expected Behavior
            \(expected.isEmpty ? "_N/A_" : expected)

            ### Actual Behavior
            \(actual.isEmpty ? "_N/A_" : actual)
            """
        }
        return body + "\n\n" + diagnostics
    }

    var issueURL: URL? {
        func encoded(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: Self.queryValue) ?? ""
        }
        return URL(string: "\(Self.newIssue)?title=\(encoded(fullTitle))&body=\(encoded(report))")
    }

    func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copied = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.copied = false
        }
    }

    func openInBrowser() {
        guard let url = issueURL else { return }
        close()
        NSWorkspace.shared.open(url)
    }

    func cancel() { close() }
}

public struct ReportIssueSheet: View {
    @State private var model: ReportIssueModel

    public init(initialCrashLog: String? = nil, initialCategory: IssueCategory = .bug) {
        _model = State(initialValue: ReportIssueModel(crashLog: initialCrashLog, category: initialCategory))
    }

    init(model: ReportIssueModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Kind", selection: $model.category) {
                        ForEach(IssueCategory.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Summary", text: $model.title,
                              prompt: Text("Dictation stops after the Mac wakes up"))
                } header: {
                    Text("Tell us what went wrong or what you would like. You check the report in your browser before anything is sent.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section("What happened") {
                    prose("What happened", $model.details, prompt: "A few sentences are plenty")
                }

                if model.category != .feature {
                    Section("Steps to reproduce") {
                        prose("Steps to reproduce", $model.steps, prompt: "1. Hold fn in Mail\n2. Speak\n3. Release")
                    }
                    Section {
                        TextField("You expected", text: $model.expected, prompt: Text("The words appear in Mail"))
                        TextField("Instead", text: $model.actual, prompt: Text("The pill stayed on transcribing"))
                    }
                }

                Section {
                    DisclosureGroup("What gets attached") {
                        Text(model.diagnostics)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } footer: {
                    Text("Version, Mac and settings only. No dictation text or audio.")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Button(model.copied ? "Copied" : "Copy Report") { model.copyReport() }
                Spacer()
                Button("Cancel", role: .cancel) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Open in Browser") { model.openInBrowser() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .tint(Look.Color.tint)
    }

    private func prose(_ label: String, _ text: Binding<String>, prompt: String) -> some View {
        TextField(label, text: text, prompt: Text(prompt), axis: .vertical)
            .lineLimit(3...10)
            .labelsHidden()
    }
}
