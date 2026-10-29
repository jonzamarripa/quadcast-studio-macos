import Foundation

public enum ProfileError: Error, LocalizedError {
    case invalidName, duplicateID, unsupportedVersion, tooLarge, tooMany, missingProfile
    public var errorDescription: String? {
        switch self {
        case .invalidName: return "Use a profile name of 1–60 characters without control characters."
        case .duplicateID: return "The file contains duplicate profile IDs. Nothing was imported."
        case .unsupportedVersion: return "This profile file uses an unsupported format version."
        case .tooLarge: return "Profile files must be no larger than 1 MB."
        case .tooMany: return "A library can contain at most 200 profiles."
        case .missingProfile: return "That profile no longer exists."
        }
    }
}
public struct ProfileDocument: Codable, Sendable {
    public var version: Int
    public var profiles: [SavedProfile]
    public init(profiles: [SavedProfile], version: Int = 1) { self.version = version; self.profiles = profiles }
    public static let maximumBytes = 1_048_576
    public static func checkedName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 60, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw ProfileError.invalidName }
        return value
    }
    public func validated() throws -> [SavedProfile] {
        guard version == 1 else { throw ProfileError.unsupportedVersion }
        guard profiles.count <= 200 else { throw ProfileError.tooMany }
        guard Set(profiles.map(\.id)).count == profiles.count else { throw ProfileError.duplicateID }
        return try profiles.map { profile in
            var result = profile
            result.name = try Self.checkedName(profile.name)
            // Validate hidden colors too, including Off and rainbow profiles.
            result.configuration.upperHex = try LightingConfiguration.checkedHex(profile.configuration.upperHex)
            result.configuration.lowerHex = try LightingConfiguration.checkedHex(profile.configuration.lowerHex)
            _ = try result.configuration.arguments()
            return result
        }
    }
    public static func decode(_ data: Data) throws -> [SavedProfile] {
        guard data.count <= maximumBytes else { throw ProfileError.tooLarge }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }
    public func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    /// Imports never replace existing IDs. Reimport creates independent copies.
    public static func merging(_ incoming: [SavedProfile], into existing: [SavedProfile]) throws -> [SavedProfile] {
        guard existing.count + incoming.count <= 200 else { throw ProfileError.tooMany }
        var result = existing
        for var profile in incoming {
            profile.id = UUID()
            let base = profile.name
            var number = 2
            while result.contains(where: { $0.name.caseInsensitiveCompare(profile.name) == .orderedSame }) {
                let suffix = " (\(number))"
                profile.name = String(base.prefix(60 - suffix.count)) + suffix
                number += 1
            }
            result.append(profile)
        }
        return try ProfileDocument(profiles: result).validated()
    }
}
