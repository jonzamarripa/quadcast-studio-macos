import Foundation

public enum LightingEffect: String, CaseIterable, Codable, Identifiable, Sendable {
    case solid = "Solid"
    case blink = "Blink"
    case cycle = "Cycle"
    case wave = "Wave"
    case lightning = "Lightning"
    case pulse = "Pulse"
    case off = "Off"

    public var id: String { rawValue }
    public var cliName: String { rawValue.lowercased() }
}

public enum LightingValidationError: Error, LocalizedError, Equatable {
    case invalidColor(String)
    case invalidBrightness
    case invalidSpeed

    public var errorDescription: String? {
        switch self {
        case let .invalidColor(value): return "Invalid RGB color: \(value). Use six hexadecimal characters."
        case .invalidBrightness: return "Brightness must be between 0 and 100."
        case .invalidSpeed: return "Effect speed must be between 0 and 100."
        }
    }
}

public struct LightingConfiguration: Codable, Equatable, Sendable {
    public var effect: LightingEffect
    public var upperHex: String
    public var lowerHex: String
    public var brightness: Int
    public var speed: Int

    public init(effect: LightingEffect, upperHex: String, lowerHex: String,
                brightness: Int = 80, speed: Int = 65) {
        self.effect = effect
        self.upperHex = upperHex
        self.lowerHex = lowerHex
        self.brightness = brightness
        self.speed = speed
    }

    public static let studioCyan = LightingConfiguration(effect: .solid, upperHex: "64E1FF", lowerHex: "64E1FF")
    public static let onAir = LightingConfiguration(effect: .solid, upperHex: "FF304B", lowerHex: "FF304B")
    public static let indigo = LightingConfiguration(effect: .solid, upperHex: "8062EF", lowerHex: "3455D1", brightness: 50)
    public static let sunset = LightingConfiguration(effect: .solid, upperHex: "F38D37", lowerHex: "AD44EA")
    public static let rainbow = LightingConfiguration(effect: .wave, upperHex: "64E1FF", lowerHex: "AD44EA")
    public static let lightsOff = LightingConfiguration(effect: .off, upperHex: "000000", lowerHex: "000000")

    /// Only known-good, explicit arguments are permitted; no shell interpolation.
    public func arguments() throws -> [String] {
        guard (0...100).contains(brightness) else { throw LightingValidationError.invalidBrightness }
        guard (0...100).contains(speed) else { throw LightingValidationError.invalidSpeed }
        if effect == .off { return ["solid", "0"] }
        let upper = try Self.checkedHex(upperHex)
        let lower = try Self.checkedHex(lowerHex)
        var args: [String] = []
        for (zone, color) in [("-u", upper), ("-l", lower)] {
            args += [zone, "-b", String(brightness)]
            if effect != .solid { args += ["-s", String(speed)] }
            args.append(effect.cliName)
            // Cycle/wave use the backend's default multi-color palette. Providing just
            // one color could produce a degenerate one-color transition.
            if effect != .cycle && effect != .wave { args.append(color) }
        }
        return args
    }

    public static func checkedHex(_ input: String) throws -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "").uppercased()
        guard normalized.count == 6,
              normalized.unicodeScalars.allSatisfy({ (48...57).contains(Int($0.value)) || (65...70).contains(Int($0.value)) }) else {
            throw LightingValidationError.invalidColor(input)
        }
        return normalized
    }
}

public struct SavedProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var configuration: LightingConfiguration

    public init(id: UUID = UUID(), name: String, configuration: LightingConfiguration) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }
}
