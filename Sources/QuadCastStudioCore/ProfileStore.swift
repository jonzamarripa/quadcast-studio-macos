import Foundation
import Combine

@MainActor
public final class ProfileStore: ObservableObject {
    @Published public private(set) var saved: [SavedProfile] = []
    @Published public private(set) var loadError: String?
    private let defaults: UserDefaults
    private let key = "QuadCastStudio.CustomProfiles.v1"
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let legacy = try JSONDecoder().decode([SavedProfile].self, from: data)
            saved = try ProfileDocument(profiles: legacy).validated()
        } catch { loadError = "Saved profiles could not be read. Existing storage has been preserved: \(error.localizedDescription)" }
    }
    public var ordered: [SavedProfile] {
        saved.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
    public func save(name: String, configuration: LightingConfiguration) throws {
        try commit(saved + [SavedProfile(name: try ProfileDocument.checkedName(name), configuration: configuration)])
    }
    public func rename(id: UUID, to name: String) throws {
        guard let index = saved.firstIndex(where: { $0.id == id }) else { throw ProfileError.missingProfile }
        var next = saved; next[index].name = try ProfileDocument.checkedName(name); try commit(next)
    }
    public func duplicate(id: UUID) throws {
        guard var profile = saved.first(where: { $0.id == id }) else { throw ProfileError.missingProfile }
        profile.name = String(profile.name.prefix(53)) + " copy"
        try commit(ProfileDocument.merging([profile], into: saved))
    }
    public func toggleFavorite(id: UUID) throws {
        guard let index = saved.firstIndex(where: { $0.id == id }) else { throw ProfileError.missingProfile }
        var next = saved; next[index].isFavorite.toggle(); try commit(next)
    }
    public func delete(id: UUID) throws { try commit(saved.filter { $0.id != id }) }
    public func importJSON(_ data: Data) throws {
        try commit(ProfileDocument.merging(ProfileDocument.decode(data), into: saved))
    }
    public func exportJSON() throws -> Data { try ProfileDocument(profiles: saved).encoded() }
    private func commit(_ next: [SavedProfile]) throws {
        // Do not silently overwrite unreadable legacy storage with an empty library.
        if let loadError { throw NSError(domain: "QuadCastStudio.Profiles", code: 1, userInfo: [NSLocalizedDescriptionKey: loadError]) }
        let validated = try ProfileDocument(profiles: next).validated()
        let data = try JSONEncoder().encode(validated)
        defaults.set(data, forKey: key)
        saved = validated
    }
}
