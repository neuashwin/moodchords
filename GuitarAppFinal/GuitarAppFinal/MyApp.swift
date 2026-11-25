import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// The on-device database for songs and moods.
    let container: ModelContainer

    init() {
        #if DEBUG
        if PreviewData.isRequestedAtLaunch {
            container = PreviewData.container()
            return
        }
        #endif
        do {
            container = try ModelContainer(for: Song.self, Mood.self)
            // First launch: create the 9 default moods.
            try MoodLibrary.seedDefaultsIfNeeded(in: container.mainContext)
            #if DEBUG
            // The owner's own songs, built into Debug builds only (personal use).
            BundledSongs.loadNew(into: container.mainContext)
            #endif
        } catch {
            fatalError("Couldn't open the song library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
