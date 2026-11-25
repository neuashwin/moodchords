//
//  Crowd.swift
//  Moodchords
//

import Foundation

/// "Who's listening?" A fixed list (not editable). Songs store crowds as plain names in
/// `Song.crowdNames`, exactly as written in the song file; this enum reads them.
nonisolated enum Crowd: String, CaseIterable, Identifiable, Hashable {
    case elders, friends, mixed, kids

    var id: Self { self }

    /// Reads a crowd tag from a song file, ignoring case and surrounding spaces.
    init?(name: String) {
        self.init(rawValue: name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    var title: String {
        switch self {
        case .elders: "Elders"
        case .friends: "Friends"
        case .mixed: "Mixed"
        case .kids: "Kids"
        }
    }

    var subtitle: String {
        switch self {
        case .elders: "Parents, relatives"
        case .friends: "Your own crowd"
        case .mixed: "Family gathering"
        case .kids: "Simple sing-alongs"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .elders: "figure.2"
        case .friends: "person.3.fill"
        case .mixed: "person.3.sequence.fill"
        case .kids: "figure.and.child.holdinghands"
        }
    }
}

/// The answer to "Who's listening?": one crowd, or "Anyone" (no filter).
nonisolated enum CrowdFilter: Hashable {
    case anyone
    case crowd(Crowd)

    var title: String {
        switch self {
        case .anyone: "Anyone"
        case .crowd(let crowd): crowd.title
        }
    }
}

extension Song {
    /// True if the song suits the chosen crowd. "Anyone" matches every song.
    func matches(_ filter: CrowdFilter) -> Bool {
        switch filter {
        case .anyone: true
        case .crowd(let crowd): crowds.contains(crowd)
        }
    }
}
