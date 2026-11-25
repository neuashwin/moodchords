import SwiftUI
import SwiftData

/// Manage moods (design 10A): drag to reorder, tap to rename or recolour, delete custom moods.
struct MoodsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]
    @Query private var songs: [Song]

    @State private var editing: MoodEditorTarget?
    @State private var pendingDelete: Mood?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Moods")
                        .themeFont(.largeTitle)
                        .foregroundStyle(Theme.fg)
                        .accessibilityAddTraits(.isHeader)
                    Text("Drag to reorder. Tap a mood to rename it. Only moods you added can be deleted.")
                        .font(Theme.font(size: 15))
                        .foregroundStyle(Theme.fg2)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                .moveDisabled(true)
                .deleteDisabled(true)
            }

            Section {
                ForEach(moods) { mood in
                    Button {
                        editing = .edit(mood)
                    } label: {
                        MoodRow(mood: mood, count: MoodLibrary.songs(for: mood, in: songs).count)
                    }
                    .buttonStyle(.plain)
                    .deleteDisabled(mood.isDefault)
                    .listRowBackground(Theme.card)
                }
                .onMove { source, destination in
                    try? MoodLibrary.move(from: source, to: destination, in: context)
                }
                .onDelete { offsets in
                    pendingDelete = offsets.first.map { moods[$0] }
                }

                Button {
                    editing = .new
                } label: {
                    Label("New mood", systemImage: "plus.circle.fill")
                        .font(Theme.font(size: 16, weight: .bold))
                        .foregroundStyle(Theme.chord)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.card)
                .moveDisabled(true)
                .deleteDisabled(true)
            }
        }
        // Always in edit mode, as in the design: drag handles and delete buttons stay visible.
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            MoodEditorSheet(target: target)
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingDelete?.name ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete mood", role: .destructive) {
                if let mood = pendingDelete { try? MoodLibrary.delete(mood, in: context) }
                pendingDelete = nil
            }
        } message: {
            Text("Songs keep their tags, so adding the mood again brings them back.")
        }
        .hidesTabBar()
    }
}

private struct MoodRow: View {
    var mood: Mood
    var count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mood.symbol)
                .font(.system(size: 16))
                .foregroundStyle(Theme.moodInk)
                .frame(width: 36, height: 36)
                .background(mood.swatch.color, in: .circle)
                .environment(\.colorScheme, .light)
                .accessibilityHidden(true)
            Text(mood.name)
                .font(Theme.font(size: 17, weight: .bold))
                .foregroundStyle(Theme.fg)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            SpecLabel(MoodTile.countLabel(for: count))
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit mood")
    }
}

// MARK: - 10B · New / edit mood

enum MoodEditorTarget: Identifiable {
    case new
    case edit(Mood)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let mood): mood.id.uuidString
        }
    }
}

/// Name, colour and icon for a mood, with a live tile preview.
struct MoodEditorSheet: View {
    var target: MoodEditorTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var hue: Double
    @State private var symbol: String
    @State private var error: String?

    /// The design's 12 colour swatches (OKLCH hues).
    static let hues: [Double] = [10, 50, 80, 105, 150, 175, 200, 225, 245, 270, 290, 330]
    /// A small curated set of icons for custom moods.
    static let symbols = [
        "moon.stars.fill", "figure.dance", "cup.and.saucer.fill", "figure.hiking", "beach.umbrella.fill",
        "music.note", "pianokeys", "music.mic", "tree.fill", "star.fill", "birthday.cake.fill", "airplane",
    ]

    /// Spoken names for the swatches (VoiceOver).
    static func colourName(_ hue: Double) -> String {
        let names: [Double: String] = [
            10: "Rose", 50: "Apricot", 80: "Amber", 105: "Olive", 150: "Green", 175: "Mint",
            200: "Teal", 225: "Sky", 245: "Blue", 270: "Periwinkle", 290: "Lavender", 330: "Orchid",
        ]
        return names[hue] ?? "Colour"
    }

    /// Spoken names for the icons (VoiceOver), falling back to the symbol name.
    static func iconName(_ symbol: String) -> String {
        let names = [
            "moon.stars.fill": "Night", "figure.dance": "Dancing", "cup.and.saucer.fill": "Coffee",
            "figure.hiking": "Hiking", "beach.umbrella.fill": "Beach", "music.note": "Music note",
            "pianokeys": "Piano", "music.mic": "Microphone", "tree.fill": "Tree", "star.fill": "Star",
            "birthday.cake.fill": "Birthday cake", "airplane": "Travel",
        ]
        return names[symbol] ?? symbol.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " ")
    }

    init(target: MoodEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _name = State(initialValue: "")
            _hue = State(initialValue: 270)
            _symbol = State(initialValue: Self.symbols[0])
        case .edit(let mood):
            _name = State(initialValue: mood.name)
            _hue = State(initialValue: mood.hue)
            _symbol = State(initialValue: mood.symbol)
        }
    }

    private var isNew: Bool { if case .new = target { true } else { false } }

    /// The curated icons, plus the mood's own icon if it isn't one of them (e.g. a default mood).
    private var symbolChoices: [String] {
        Self.symbols.contains(symbol) ? Self.symbols : [symbol] + Self.symbols.dropLast()
    }

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MoodTile(mood: MoodSwatch(name: trimmed.isEmpty ? "Hostel nights" : trimmed,
                                              symbol: symbol, hue: hue),
                             countLabel: "Preview")
                        .frame(width: 200)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    TextField("Mood name", text: $name, prompt: Text("Hostel nights"))
                        .font(Theme.font(size: 18, weight: .bold))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Theme.card2, in: .rect(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.5) }
                        .padding(.top, 20)
                        .onChange(of: name) { error = nil }
                    if let error {
                        Text(error)
                            .font(Theme.font(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .padding(.top, 6)
                            .padding(.horizontal, 4)
                    }

                    SpecLabel("Colour").padding(.top, 18).padding(.horizontal, 4).padding(.bottom, 10)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(Self.hues, id: \.self) { option in
                            HueSwatch(hue: option, isSelected: option == hue) { hue = option }
                        }
                    }

                    SpecLabel("Icon").padding(.top, 18).padding(.horizontal, 4).padding(.bottom, 10)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(symbolChoices, id: \.self) { option in
                            IconOption(symbol: option, isSelected: option == symbol) { symbol = option }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle(isNew ? "New mood" : "Edit mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationCornerRadius(46)
        .presentationBackground(Theme.sheet)
    }

    private func save() {
        do {
            switch target {
            case .new:
                try MoodLibrary.addMood(name: name, symbol: symbol, hue: hue, in: context)
            case .edit(let mood):
                try MoodLibrary.update(mood, name: name, symbol: symbol, hue: hue, in: context)
            }
            dismiss()
        } catch MoodLibrary.RenameError.duplicateName {
            error = "You already have a mood with that name."
        } catch {
            self.error = "Couldn't save the mood."
        }
    }
}

/// One colour choice: a mood-coloured circle, ringed and checked when selected.
private struct HueSwatch: View {
    var hue: Double
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(moodHue: hue))
                    .frame(width: 44, height: 44)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.moodInk)
                    Circle()
                        .strokeBorder(Theme.fg, lineWidth: 2.5)
                        .frame(width: 50, height: 50)
                }
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MoodEditorSheet.colourName(hue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One icon choice; inverted when selected.
private struct IconOption: View {
    var symbol: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Theme.sheet : Theme.fg)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(isSelected ? Theme.fg : Theme.chip, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MoodEditorSheet.iconName(symbol))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("10A · Moods", traits: .sampleLibrary) {
    NavigationStack { MoodsScreen() }
}

#Preview("10B · New mood", traits: .sampleLibrary) {
    MoodEditorSheet(target: .new)
}
