import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The app's root: four tabs with the floating glass tab bar at the bottom.
struct RootView: View {
    @State private var selection: AppTab = .moods
    /// Deeper screens (song list, song) hide the bar via `.hidesTabBar()`.
    @State private var tabBar = TabBarVisibility()
    /// Add song, Paste, Import and Edit, openable from any screen.
    @State private var router = SheetRouter()

    @Environment(\.modelContext) private var context
    @Query(sort: \Mood.sortOrder) private var moods: [Mood]

    var body: some View {
        // The system TabView keeps every tab alive (each keeps its scroll position and
        // navigation) and properly hides unselected tabs from VoiceOver. Its own bar is
        // hidden so the design's glass bar shows instead.
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(value: tab) {
                    // Each tab's top screen reserves room for the bar itself (`.clearsTabBar()`),
                    // inside its navigation stack, where the inset actually reaches the content.
                    screen(for: tab)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !tabBar.isHidden {
                GlassTabBar(selection: $selection)
                    // The design floats the bar 26 pt from the screen edge, a little into the home-indicator area.
                    .padding(.bottom, -8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: tabBar.isHidden)
        .sheet(item: $router.sheet, onDismiss: router.sheetDidDismiss) { sheet in
            switch sheet {
            case .addSong:
                AddSongEntrySheet().fittedSheet()
            case .paste(let text):
                PasteSongScreen(initialText: text)
            case .importResult(let report):
                ImportResultScreen(report: report)
            case .editSong(let song):
                EditSongScreen(song: song)
            }
        }
        .fileImporter(
            isPresented: $router.isImporting,
            allowedContentTypes: SongImporter.allowedTypes + [.folder],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            let report = SongImporter.importFiles(urls, into: context, knownMoods: moods.map(\.name))
            router.show(.importResult(report))
        }
        .onChange(of: router.requestedTab) {
            if let tab = router.requestedTab {
                selection = tab
                router.requestedTab = nil
            }
        }
        .environment(tabBar)
        .environment(router)
    }

    /// Bar height (66) minus how far it dips into the home-indicator area (8).
    static let tabBarClearance: CGFloat = 58

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .moods:
            HomeScreen()
        case .favourites:
            FavouritesScreen()
        case .setlists:
            PlaceholderScreen(title: "Setlists", symbol: "music.note.list", message: "Coming in M5")
                .clearsTabBar()
        case .tuner:
            TunerScreen()
                .clearsTabBar()
        }
    }
}

#Preview("Light") {
    RootView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.light)
}

#Preview("Dark (stage)") {
    RootView()
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
}
