import SwiftUI
import UIKit

/// A monospaced editor for song text with `[chords]` in the chord colour, `{directives}`
/// dimmed and problem lines shaded. It grows with its text (no inner scrolling), so it can
/// sit inside a ScrollView with other content.
struct SongTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// 1-based line numbers to shade as problems.
    var problemLines: Set<Int> = []

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        // Song text: no autocorrect, and no smart quotes or dashes ({title: …} must stay plain).
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.keyboardDismissMode = .interactive
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // A "Done" bar above the keyboard, so it can always be put away.
        let bar = UIToolbar()
        bar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak view] _ in view?.resignFirstResponder() }),
        ]
        bar.tintColor = UIColor(Theme.chord)
        bar.sizeToFit()
        view.inputAccessoryView = bar
        view.text = text
        context.coordinator.highlight(view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            view.text = text
        }
        context.coordinator.highlight(view)
    }

    /// Grows to fit the text at the proposed width.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, 220))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SongTextEditor

        init(_ parent: SongTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            highlight(textView)
        }

        private static let font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        private static let chordFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        private static let chordPattern = try? NSRegularExpression(pattern: #"\[[^\]\n]*\]"#)
        private static let directivePattern = try? NSRegularExpression(
            pattern: #"^[ \t]*\{[ \t]*[A-Za-z_]+[ \t]*(:[^\n]*)?\}[ \t]*$"#, options: .anchorsMatchLines
        )

        /// Re-colours the whole text in place. Skipped while the keyboard is composing
        /// (marked text), which some Devanagari keyboards use, so typing isn't interrupted.
        func highlight(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            let storage = textView.textStorage
            let text = storage.string as NSString
            let all = NSRange(location: 0, length: text.length)
            let base: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: UIColor(Theme.fg)]

            storage.beginEditing()
            storage.setAttributes(base, range: all)

            // Shade problem lines.
            var lineNumber = 1
            text.enumerateSubstrings(in: all, options: [.byLines, .substringNotRequired]) { _, _, enclosing, _ in
                if self.parent.problemLines.contains(lineNumber) {
                    storage.addAttribute(.backgroundColor, value: UIColor(Theme.errorBackground), range: enclosing)
                }
                lineNumber += 1
            }
            Self.directivePattern?.enumerateMatches(in: storage.string, range: all) { match, _, _ in
                if let range = match?.range {
                    storage.addAttribute(.foregroundColor, value: UIColor(Theme.fg2), range: range)
                }
            }
            Self.chordPattern?.enumerateMatches(in: storage.string, range: all) { match, _, _ in
                if let range = match?.range {
                    storage.addAttributes([.foregroundColor: UIColor(Theme.chord), .font: Self.chordFont], range: range)
                }
            }
            storage.endEditing()
            textView.typingAttributes = base
        }
    }
}

/// Puts away the keyboard, whichever field or editor has it.
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// A list of parser problems ("Line 4: Couldn't read capo…") under an editor.
struct IssueList: View {
    var warnings: [ParseWarning]

    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(Theme.danger)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Line \(warning.line)")
                                .themeFont(.mono)
                                .foregroundStyle(Theme.fg2)
                            Text(warning.message)
                                .font(Theme.font(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.fg)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.errorBackground, in: .rect(cornerRadius: 22))
        }
    }
}

/// The red "this can't be saved" banner (design 7B).
struct ErrorBanner: View {
    var title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.font(.bodyStrong))
                    .foregroundStyle(Theme.danger)
                if let detail {
                    Text(detail)
                        .font(Theme.font(size: 14))
                        .foregroundStyle(Theme.fg)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.errorBackground, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// What the parser thinks of some song text, for the paste and edit screens.
struct SongCheck {
    var parsed: ParsedSong?
    var error: ParseError?
    /// True when chords-above-lyrics will be moved inline on save (line numbers then refer to the result).
    var willConvert: Bool

    init(text: String) {
        let converted = ChordSheetConverter.convertIfNeeded(text)
        willConvert = converted != text
        do {
            parsed = try ChordProParser.parse(converted)
            error = nil
        } catch let parseError as ParseError {
            parsed = nil
            error = parseError
        } catch {
            parsed = nil
            self.error = .empty
        }
    }

    /// Parser warnings worth showing while editing. The "no duration" note is left out
    /// because the length field covers it.
    var warnings: [ParseWarning] {
        (parsed?.warnings ?? []).filter { !$0.message.hasPrefix("No {duration:}") }
    }

    var problemLines: Set<Int> { willConvert ? [] : Set(warnings.map(\.line)) }
}
