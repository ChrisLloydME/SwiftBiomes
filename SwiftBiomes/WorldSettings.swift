import Foundation
import CubiomesCore

struct MinecraftVersionOption: Equatable, Hashable, Sendable {
    let label: String
    let version: MinecraftVersion

    nonisolated static let supported: [MinecraftVersionOption] = [
        .init(label: "1.21", version: .v1_21),
        .init(label: "1.20", version: .v1_20),
        .init(label: "1.19", version: .v1_19),
        .init(label: "1.18", version: .v1_18),
        .init(label: "1.17", version: .v1_17),
        .init(label: "1.16", version: .v1_16),
        .init(label: "1.15", version: .v1_15),
        .init(label: "1.14", version: .v1_14),
        .init(label: "1.13", version: .v1_13),
        .init(label: "1.12", version: .v1_12),
        .init(label: "1.8", version: .v1_8)
    ]
}

enum DimensionOption: String, CaseIterable, Equatable, Hashable, Sendable {
    case overworld = "Overworld"
    case nether = "Nether"
    case end = "End"

    nonisolated var dimension: MinecraftDimension {
        switch self {
        case .overworld:
            return .overworld
        case .nether:
            return .nether
        case .end:
            return .end
        }
    }
}

struct WorldSettings: Equatable, Hashable, Sendable {
    var seed: Int64
    var version: MinecraftVersionOption
    var dimension: DimensionOption

    nonisolated static let sample = WorldSettings(
        seed: 262,
        version: MinecraftVersionOption.supported.first { $0.label == "1.18" }!,
        dimension: .overworld
    )
}

struct BiomeQueryRequest: Equatable, Hashable, Sendable {
    var settings: WorldSettings
    var x: Int32
    var z: Int32
}

struct BiomeDisplayResult: Equatable, Sendable {
    let id: Int32
    let name: String
    let x: Int32
    let z: Int32
    let settings: WorldSettings

    var title: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
