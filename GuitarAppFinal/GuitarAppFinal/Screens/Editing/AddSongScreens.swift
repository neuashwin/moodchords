import SwiftUI
import SwiftData

// MARK: - 7A · Entry sheet

/// "Add a song": paste, import a file or folder, or start from the template.
struct AddSongEntrySheet: View {
    @Environment(SheetRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add a song")
                .font(Theme.font(.sheetTitle))
                .foregroundStyle(Theme.fg)
                .accessibilityAddTraits(.isHeader)
            Text("Bring in songs you already play.")
                .font(Theme.font(size: 16))
                .foregroundStyle(Theme.fg2)
                .padding(.top, 6)

            VStack(spacing: 10) {
                row(title: "Paste song",
                    detail: "Lyrics with [chords] from notes or a website",
                    symbol: "doc.on.clipboard", accent: true) { router.paste() }
                row(title: "Import file",
                    detail: ".txt or ChordPro (.cho), one song or a whole folder",
                    symbol: "arrow.up.doc", accent: false) { router.importFiles() }
            }
            .padding(.top, 20)

            Button {
                router.paste(SongImporter.template)
            } label: {
                Label("Start from the template", systemImage: "doc.text")
                    .font(Theme.font(size: 15, weight: .bold))
                    .foregroundStyle(Theme.chord)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func row(title: String, detail: String, symbol: String, accent: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accent ? .white : Theme.fg)
                    .frame(width: 52, height: 52)
                    .background {
                        if accent {
                            Circle().fill(Theme.accentGradient)
                        } else {
                            Circle().fill(Theme.chip)
                        }
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.font(size: 19, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text(detail)
                        .font(Theme.font(size: 14))
                        .foregroundStyle(Theme.fg2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.fg3)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Theme.card2, in: .rect(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line, lineWidth: 0.5) }
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 7B · Paste

/// Paste or type a song, with live problems shown above the editor. Save adds it to the library.
struct PasteSongScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var confirmTemplate = false
    @State private var saveError: String?

    init(initialText: String) {
        _text = State(initialValue: initialText)
    }

    var body: some View {
        let check = SongCheck(text: text)
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let issueCount = check.warnings.count + (check.error == .missingTitle ? 1 : 0)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Button {
                            if isEmpty { text = SongImporter.template } else { confirmTemplate = true }
                        } label: {
                            Label("Template", systemImage: "doc.text")
                                .font(Theme.font(size: 15, weight: .bold))
                                .foregroundStyle(Theme.fg)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(Theme.chip, in: .capsule)
                        }
                        .buttonStyle(.plain)

                        // The system paste button doesn't ask for clipboard permission.
                        PasteButton(payloadType: String.self) { strings in
                            let pasted = strings.joined(separator: "\n")
                            Task { @MainActor in insertPasted(pasted) }
                        }
                        .buttonBorderShape(.capsule)
                        .labelStyle(.titleAndIcon)
                        .tint(Theme.chord)

                        Spacer()
                        if issueCount > 0 {
                            SpecLabel(issueCount == 1 ? "1 issue" : "\(issueCount) issues")
                        }
                    }

                    if check.error == .missingTitle {
                        ErrorBanner(title: "The song needs a title",
                                    detail: "Add a first line like {title: Campfire Night}")
                    }
                    if let saveError {
                        ErrorBanner(title: "Couldn't save", detail: saveError)
                    }
                    if check.willConvert {
                        Text("Chords written above the lyrics will be moved into the lines when you save.")
                            .font(Theme.font(size: 14))
                            .foregroundStyle(Theme.fg2)
                    }
                    IssueList(warnings: check.warnings)

                    SongTextEditor(text: $text, problemLines: check.problemLines)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Paste a chord sheet here, or tap Template.")
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(Theme.fg3)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 24))
                        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.5) }

                    Text("Put each chord in [brackets] right before the word it lands on.")
                        .font(Theme.font(size: 14))
                        .foregroundStyle(Theme.fg2)
                        .padding(.horizontal, 8)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Paste song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(check.parsed == nil)
                }
            }
            .confirmationDialog("Replace your text with the template?", isPresented: $confirmTemplate) {
                Button("Replace", role: .destructive) { text = SongImporter.template }
            }
        }
        // Don't lose a half-pasted song to an accidental swipe.
        .interactiveDismissDisabled(!isEmpty)
    }

    private func insertPasted(_ pasted: String) {
        let combined = text.isEmpty ? pasted : text + "\n" + pasted
        // Sheets copied from chord sites put chords above the lyrics; move them inline now,
        // so what you see is what gets saved.
        text = ChordSheetConverter.convertIfNeeded(combined)
    }

    private func save() {
        do {
            _ = try SongImporter.importText(text, into: context)
            try context.save()
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - 7C · Import result

/// "Added 10 songs", the titles, and friendly things to check.
struct ImportResultScreen: View {
    var report: ImportReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let added = report.addedTitles.count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let didSomething = added > 0 || report.languageUpdates > 0
                    Image(systemName: didSomething ? "checkmark" : "tray")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(didSomething ? Theme.ok : Theme.fg2)
                        .frame(width: 76, height: 76)
                        .background(didSomething ? Theme.okBackground : Theme.chip, in: .circle)
                        .accessibilityHidden(true)

                    Text(headline)
                        .font(Theme.font(size: 40, weight: .heavy))
                        .foregroundStyle(Theme.fg)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .themeFont(.body)
                        .foregroundStyle(Theme.fg2)
                        .padding(.top, 8)

                    if added > 0 {
                        FlowLayout(rowSpacing: 6, itemSpacing: 6) {
                            ForEach(Array(report.addedTitles.prefix(5).enumerated()), id: \.offset) { _, title in
                                Chip(title: title)
                            }
                            if added > 5 {
                                Text("+\(added - 5) more")
                                    .font(Theme.font(.callout))
                                    .foregroundStyle(Theme.fg2)
                                    .frame(height: 32)
                            }
                        }
                        .padding(.top, 16)
                    }

                    if !report.checks.isEmpty {
                        SpecLabel(report.checks.count == 1 ? "1 thing to check" : "\(report.checks.count) things to check")
                            .padding(.top, 28)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        checksCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .background(Theme.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                AccentCapsuleButton(title: added > 0 ? "Go to my moods" : "Close",
                                    symbol: added > 0 ? "square.grid.2x2.fill" : "xmark") { dismiss() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headline: String {
        let added = report.addedTitles.count
        if added == 0 {
            return report.languageUpdates > 0 ? "Updated \(CrowdSheet.songCount(report.languageUpdates))" : "No new songs"
        }
        return added == 1 ? "Added 1 song" : "Added \(added) songs"
    }

    private var subtitle: String {
        let files = report.fileCount == 1 ? "1 file" : "\(report.fileCount) files"
        var text = report.folderName.map { "From \(files) in \u{201C}\($0)\u{201D}." } ?? "From \(files)."
        if !report.addedTitles.isEmpty { text += " They're sorted into your moods already." }
        if report.languageUpdates > 0 {
            text += " Set the language of \(CrowdSheet.songCount(report.languageUpdates)) you already had, from their folder names."
        }
        return text
    }

    private var checksCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(report.checks.enumerated()), id: \.element.id) { index, check in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 0.5) }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol(for: check.kind))
                        .font(.system(size: 18))
                        .foregroundStyle(check.kind == .skipped ? Theme.fg2 : Theme.chord)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                            .font(Theme.font(size: 16, weight: .bold))
                            .foregroundStyle(Theme.fg)
                        Text(check.message)
                            .font(Theme.font(size: 14))
                            .foregroundStyle(Theme.fg2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
            }
        }
        .background(Theme.card, in: .rect(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.line, lineWidth: 0.5) }
    }

    private func symbol(for kind: ImportReport.Check.Kind) -> String {
        switch kind {
        case .length: "clock"
        case .key: "music.note"
        case .mood: "square.grid.2x2"
        case .skipped: "nosign"
        case .problem: "exclamationmark.triangle"
        }
    }
}

#if DEBUG
#Preview("7B · Paste with error") {
    PasteSongScreen(initialText: "[G]Sparks are rising [C]up into the [G]sky\n{capo: high}")
        .modelContainer(PreviewData.container(withSongs: false))
}

#Preview("7C · Import result") {
    var report = ImportReport()
    report.addedTitles = ["Campfire Night", "साँझको गीत"]
    report.fileCount = 3
    report.folderName = "Jam songs"
    report.checks = [
        .init(title: "साँझको गीत", kind: .length, message: "No {duration:} found. Auto-scroll will assume 3:30."),
        .init(title: "Campfire Night", kind: .key, message: "No key set. Add {key: G} so the cue card can show it."),
        .init(title: "notes.pdf", kind: .skipped, message: "Skipped. It isn't a song file."),
    ]
    return ImportResultScreen(report: report)
}
#endif
