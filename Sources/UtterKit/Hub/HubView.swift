import SwiftUI

/// The menu-bar hub: the J-card's front flap.
struct HubView: View {
    @Bindable var model: HubModel

    static let width: CGFloat = 384
    private static let listHeight = Mixtape.ruleSpacing * 8

    var body: some View {
        VStack(spacing: 0) {
            TapeStripe(model.stripeLabel, status: model.status, segments: model.segments, goal: model.goal) { id in
                if let track = model.today.first(where: { $0.id == id }) { model.perform(.open(track)) }
            }
            VStack(alignment: .leading, spacing: 0) {
                header
                setupLine
                LineField("Search what you said", text: $model.query).padding(.top, 10)
                list.padding(.top, 2)
                DeckKeys([
                    DeckKey("Hands-free", systemImage: "lock.fill", isOn: model.handsFree) { model.perform(.handsFree) },
                    DeckKey("New note", systemImage: "doc.text") { model.perform(.newNote) },
                    DeckKey("Record meeting", systemImage: "record.circle", accent: Mixtape.red) { model.perform(.recordMeeting) },
                ])
                .padding(.top, 14)
                footer.padding(.top, 12)
                hints.padding(.top, 8)
            }
            .padding(EdgeInsets(top: 14, leading: 18, bottom: 12, trailing: 18))
        }
        .frame(width: Self.width)
        .background(Mixtape.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Mixtape.edge))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utter")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.heading).mixtapeCaps(12, tracking: 0.22).foregroundStyle(Mixtape.ink).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(model.detail).font(Mixtape.mono(11, .semibold)).foregroundStyle(Mixtape.ink3)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var setupLine: some View {
        if let message = model.message {
            Text(message)
                .font(Mixtape.body(12.5))
                .foregroundStyle(Mixtape.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        } else if let need = model.needs.first {
            HStack(spacing: 10) {
                (Text(HubNeed.title(model.needs.count) + ".").fontWeight(.semibold).foregroundStyle(Mixtape.ink) + Text(" " + need.message))
                    .font(Mixtape.body(12.5))
                    .foregroundStyle(Mixtape.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(need.button) { model.perform(.grant(need)) }.buttonStyle(.pen(.fill, .small))
            }
            .padding(.top, 10)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if model.rows.isEmpty {
                        empty
                    } else {
                        ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, track in
                            row(track, selected: index == model.selection)
                                .id(track.id)
                                .onHover { if $0 { model.selection = index } }
                                .onTapGesture { model.selection = index }
                        }
                    }
                }
                .frame(minHeight: Self.listHeight, alignment: .top)
                .background(alignment: .top) { RuledBackground() }
                .padding(.leading, 8)
            }
            .padding(.leading, -8)
            .frame(height: Self.listHeight)
            .id(model.openCount)
            .onChange(of: model.selection) {
                if let id = model.selected?.id { proxy.scrollTo(id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.searching ? "Found" : "Today's tracks")
    }

    @ViewBuilder
    private func row(_ track: HubTrack, selected: Bool) -> some View {
        let row = TrackRow(number: track.number, title: track.title, time: track.time, selected: selected,
                           ticked: model.pasted.contains(track.id), emphasized: track.kind == .meeting,
                           highlight: model.searching ? model.query.trimmingCharacters(in: .whitespaces) : "") {
            if track.kind == .meeting {
                Button { model.perform(.open(track)) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.inkIcon).accessibilityLabel("Open in Library")
            } else {
                Button { model.copy(track) } label: { Image(systemName: model.copiedID == track.id ? "checkmark" : "square.on.square") }
                    .buttonStyle(.inkIcon).accessibilityLabel(model.copiedID == track.id ? "Copied" : "Copy")
                Button { model.perform(.paste(track)) } label: { Image(systemName: "arrow.turn.down.left") }
                    .buttonStyle(.inkIcon).accessibilityLabel(pasteLabel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: track.kind == .meeting ? "Open in Library" : pasteLabel) {
            model.perform(track.kind == .meeting ? .open(track) : .paste(track))
        }
        if track.id == model.fresh { row.modifier(WriteOn()) } else { row }
    }

    private var pasteLabel: String { model.targetApp.isEmpty ? "Paste again" : "Paste in \(model.targetApp)" }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.searching ? "Nothing matches \u{201C}\(model.query.trimmingCharacters(in: .whitespaces))\u{201D}" : "Nothing on today\u{2019}s tape yet")
                .fontWeight(.semibold).foregroundStyle(Mixtape.ink2)
            Text(model.searching ? "Utter looks through every track, note and meeting on this Mac."
                                 : "Hold \(model.hotkey) and talk; every track lands here.")
        }
        .font(Mixtape.body(12.5))
        .foregroundStyle(Mixtape.ink3)
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button { model.perform(.openLibrary) } label: {
                HStack(spacing: 8) { Text("Open Library"); Keycap("\u{2303}\u{2325}U") }
            }
            .buttonStyle(LinkStyle())
            .accessibilityLabel("Open Library")
            Spacer(minLength: 0)
            Button("Settings") { model.perform(.settings) }.buttonStyle(LinkStyle())
            Menu {
                Button("What\u{2019}s New") { model.perform(.whatsNew) }
                Button("Report an Issue\u{2026}") { model.perform(.reportIssue) }
                Divider()
                Button("Quit Utter") { model.perform(.quit) }.keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.inkIcon)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
    }

    private var hints: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) { Keycap("\u{2191}"); Keycap("\u{2193}"); Text("choose") }
            HStack(spacing: 4) {
                Keycap("\u{21A9}")
                if model.selected?.kind == .meeting {
                    Text("open")
                } else if model.targetApp.isEmpty {
                    Text("paste")
                } else {
                    Text("paste in"); Text(model.targetApp).fontWeight(.bold).foregroundStyle(Mixtape.ink2)
                }
            }
            HStack(spacing: 4) { Keycap("\u{2318}C"); Text("copy") }
            HStack(spacing: 4) { Keycap("\u{2318}O"); Text("open") }
        }
        .font(Mixtape.body(11))
        .foregroundStyle(Mixtape.ink3)
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}

/// The footer's plain text links: ink, a wash on hover.
private struct LinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Link(configuration: configuration)
    }

    private struct Link: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(Mixtape.body(12.5, .semibold))
                .foregroundStyle(Mixtape.ink)
                .padding(.horizontal, 6)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hovering ? Mixtape.wash : .clear))
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hovering = $0 }
        }
    }
}

