import SwiftUI
import SwiftData

/// Edit a song (design 8A/8B). The song's text is the single source of truth: the fields and
/// chips at the top rewrite its `{title:}`, `{key:}`, `{mood:}`… lines, and the editor below
/// shows all of it. Done re-reads the text and updates the song.
struct EditSongScreen: View {
    var song: Song

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]

    @State private var text: String
    @State private var mode: Mode = .edit
    @State private var confirmDiscard = false
    @State private var confirmDelete = false

    // Local copies of the header fields, so typing (including spaces) isn't disturbed by trimming.
    @State private var title = ""
    @State private var artist = ""
    @State private var key = ""
    @State private var capo = ""
    @State private var length = ""

    enum Mode: String, CaseIterable {
        case edit = "Edit"
        case preview = "Live preview"
    }

    init(song: Song) {
        self.song = song
        _text = State(initialValue: song.source)
    }

    var body: some View {
        let check = SongCheck(text: text)
        let hasChanges = text != song.source

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)

                    fieldsCard.padding(.top, 12)
                    specCards.padding(.top, 8)

                    SpecLabel("Moods").padding(.top, 16).padding(.horizontal, 4)
                    moodChips.padding(.top, 8)
                    SpecLabel("Crowd").padding(.top, 16).padding(.horizontal, 4)
                    crowdChips.padding(.top, 8)
                    SpecLabel("Language").padding(.top, 16).padding(.horizontal, 4)
                    languageChips.padding(.top, 8)

                    if check.error == .missingTitle {
                        ErrorBanner(title: "The song needs a title", detail: "Fill in Title above.")
                            .padding(.top, 14)
                    }
                    IssueList(warnings: check.warnings).padding(.top, 14)

                    Group {
                        switch mode {
                        case .edit:
                            SongTextEditor(text: $text, problemLines: check.problemLines)
                        case .preview:
                            if let parsed = check.parsed {
                                ChordSheetView(lines: parsed.lines)
                                    .tint(Theme.chord)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                            } else {
                                Text("Fix the problems above to see the preview.")
                                    .themeFont(.body)
                                    .foregroundStyle(Theme.fg2)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                            }
                        }
                    }
                    .background(Theme.card, in: .rect(cornerRadius: 24))
                    .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.5) }
                    .padding(.top, 14)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete song", systemImage: "trash")
                            .font(Theme.font(size: 16, weight: .bold))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Edit song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(check) }
                        .disabled(check.parsed == nil)
                }
                // Above the keyboard for the title/artist/key/capo/length fields.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Delete \u{201C}\(song.title)\u{201D}?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete song", role: .destructive) { delete() }
            } message: {
                Text("This removes it from your library. It can't be undone.")
            }
            .onAppear(perform: refreshFields)
            .onChange(of: text) { refreshFields() }
            .onChange(of: title) { write(.title, title) }
            .onChange(of: artist) { write(.artist, artist) }
            .onChange(of: key) { write(.key, key) }
            .onChange(of: capo) { write(.capo, capo) }
            .onChange(of: length) { write(.duration, length) }
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: Fields

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow("Title", text: $title, weight: .bold)
            Rectangle().fill(Theme.line).frame(height: 0.5)
            fieldRow("Artist", text: $artist, weight: .semibold)
        }
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.line, lineWidth: 0.5) }
    }

    private func fieldRow(_ label: String, text: Binding<String>, weight: Font.Weight) -> some View {
        HStack(spacing: 12) {
            SpecLabel(label)
                .frame(width: 62, alignment: .leading)
            TextField(label, text: text)
                .font(Theme.font(size: 17, weight: weight))
                .foregroundStyle(Theme.fg)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private var specCards: some View {
        HStack(spacing: 8) {
            specCard("Key", text: $key, prompt: "G", keyboard: .asciiCapable)
            specCard("Capo", text: $capo, prompt: "None", keyboard: .numberPad)
            specCard("Length", text: $length, prompt: "3:30", keyboard: .numbersAndPunctuation)
        }
    }

    private func specCard(_ label: String, text: Binding<String>, prompt: String,
                          keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Theme.font(size: 10.5, mono: true))
                .foregroundStyle(Theme.fg2)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Theme.fg3))
                .font(Theme.font(size: 19, weight: .heavy))
                .foregroundStyle(Theme.fg)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.5) }
    }

    // MARK: Chips

    private var moodChips: some View {
        let tags = SourceEditing.list(of: .mood, in: text)
        // Tags that aren't (yet) moods in the library still show, so they can be removed.
        let unknown = tags.filter { tag in !moods.contains { $0.matches(name: tag) } }
        return FlowLayout(rowSpacing: 6, itemSpacing: 6) {
            ForEach(moods) { mood in
                let isOn = tags.contains { mood.matches(name: $0) }
                Button {
                    toggleMood(mood.name, in: tags)
                } label: {
                    Chip(title: mood.name, style: isOn ? .mood(mood.swatch) : .plain)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            ForEach(unknown, id: \.self) { tag in
                Button {
                    toggleMood(tag, in: tags)
                } label: {
                    Chip(title: tag, style: .selected)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Not one of your moods. Tap to remove.")
            }
        }
    }

    private var crowdChips: some View {
        let tags = SourceEditing.list(of: .crowd, in: text)
        return FlowLayout(rowSpacing: 6, itemSpacing: 6) {
            ForEach(Crowd.allCases) { crowd in
                let isOn = tags.contains { Crowd(name: $0) == crowd }
                Button {
                    dismissKeyboard()
                    let updated = isOn ? tags.filter { Crowd(name: $0) != crowd } : tags + [crowd.title]
                    text = SourceEditing.setting(.crowd, toList: updated, in: text)
                } label: {
                    Chip(title: crowd.title, style: isOn ? .selected : .option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One language (or none): tap the chosen one again to clear it.
    private var languageChips: some View {
        let current = SongLanguage(name: SourceEditing.value(of: .language, in: text))
        return FlowLayout(rowSpacing: 6, itemSpacing: 6) {
            ForEach(SongLanguage.allCases) { language in
                let isOn = language == current
                Button {
                    dismissKeyboard()
                    text = SourceEditing.setting(.language, to: isOn ? nil : language.title, in: text)
                } label: {
                    Chip(title: language.title, style: isOn ? .selected : .option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleMood(_ name: String, in tags: [String]) {
        dismissKeyboard()
        let key = MoodLibrary.normalized(name)
        let isOn = tags.contains { MoodLibrary.normalized($0) == key }
        let updated = isOn ? tags.filter { MoodLibrary.normalized($0) != key } : tags + [name]
        text = SourceEditing.setting(.mood, toList: updated, in: text)
    }

    // MARK: Syncing fields with the text

    private func write(_ field: SourceEditing.Field, _ value: String) {
        let current = SourceEditing.value(of: field, in: text) ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard current != trimmed else { return }
        text = SourceEditing.setting(field, to: trimmed, in: text)
    }

    /// Pulls field values from the text, leaving a field alone if it only differs by spaces
    /// (so a space you just typed isn't removed).
    private func refreshFields() {
        func sync(_ field: Binding<String>, _ directive: SourceEditing.Field) {
            let value = SourceEditing.value(of: directive, in: text) ?? ""
            if field.wrappedValue.trimmingCharacters(in: .whitespaces) != value {
                field.wrappedValue = value
            }
        }
        sync($title, .title)
        sync($artist, .artist)
        sync($key, .key)
        sync($capo, .capo)
        sync($length, .duration)
    }

    // MARK: Save / delete

    private func save(_ check: SongCheck) {
        guard let parsed = check.parsed else { return }
        song.update(parsed: parsed, source: ChordSheetConverter.convertIfNeeded(text))
        try? context.save()
        dismiss()
    }

    private func delete() {
        context.delete(song)
        try? context.save()
        dismiss()
    }
}

#if DEBUG
private struct EditSongPreview: View {
    @Query private var songs: [Song]
    var body: some View {
        if let song = songs.first(where: { $0.title == "Campfire Night" }) {
            EditSongScreen(song: song)
        }
    }
}

#Preview("8A · Edit", traits: .sampleLibrary) {
    EditSongPreview()
}
#endif
