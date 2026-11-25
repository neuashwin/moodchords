import SwiftUI
import SwiftData

/// The app-wide sheets: Add song, Paste, Import result and Edit song. Any screen can open
/// them; `RootView` presents them, so they work the same from every tab.
enum AppSheet: Identifiable {
    case addSong
    case paste(initialText: String)
    case importResult(ImportReport)
    case editSong(Song)

    var id: String {
        switch self {
        case .addSong: "add"
        case .paste: "paste"
        case .importResult(let report): "import-\(report.id)"
        case .editSong(let song): "edit-\(song.persistentModelID.hashValue)"
        }
    }
}

@Observable
final class SheetRouter {
    var sheet: AppSheet?
    /// Shows the system file picker.
    var isImporting = false
    /// Set to switch tabs from deep inside a screen (e.g. the song page's "Tuner" link).
    var requestedTab: AppTab?

    /// What to show once the current sheet has finished closing. Swapping one sheet straight
    /// for another isn't reliable, so the next one waits for the first to go.
    private enum Next {
        case sheet(AppSheet)
        case importer
    }
    private var next: Next?

    func addSong() { show(.addSong) }
    func paste(_ text: String = "") { show(.paste(initialText: text)) }
    func edit(_ song: Song) { show(.editSong(song)) }

    func importFiles() {
        if sheet != nil {
            next = .importer
            sheet = nil
        } else {
            isImporting = true
        }
    }

    /// Shows a sheet, or queues it if another sheet is up.
    func show(_ newSheet: AppSheet) {
        if sheet != nil {
            next = .sheet(newSheet)
            sheet = nil
        } else {
            sheet = newSheet
        }
    }

    /// Called by RootView when any app sheet finishes closing.
    func sheetDidDismiss() {
        guard let pending = next else { return }
        next = nil
        switch pending {
        case .sheet(let newSheet): sheet = newSheet
        case .importer: isImporting = true
        }
    }
}

extension View {
    /// Sheet styling from the design: sized to its content, rounded 46, sheet colour, grabber.
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}

private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 420

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(46)
            .presentationBackground(Theme.sheet)
    }
}
