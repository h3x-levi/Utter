import SwiftUI

struct VoiceEngineView: View {
    @State private var model: WordsViewModel

    @MainActor
    init(model: WordsViewModel? = nil) {
        _model = State(initialValue: model ?? WordsViewModel())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Look.Space.x4) {
            Picker("Words section", selection: $model.section) {
                ForEach(WordsViewModel.Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 400)

            switch model.section {
            case .dictionary: DictionarySection(model: model)
            case .snippets: SnippetsSection(model: model)
            case .commands: CommandsSection(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Look.Color.ground)
        .onAppear { model.reload() }
    }
}
