import Foundation
import CubiomesCore

protocol BiomeProviding: Sendable {
    nonisolated func biome(for request: BiomeQueryRequest) throws -> BiomeDisplayResult
}

struct CubiomesBiomeService: BiomeProviding {
    nonisolated init() {}

    nonisolated func biome(for request: BiomeQueryRequest) throws -> BiomeDisplayResult {
        let result = try CubiomesCore.biome(
            version: request.settings.version.version,
            seed: request.settings.seed,
            dimension: request.settings.dimension.dimension,
            x: request.x,
            z: request.z
        )

        return BiomeDisplayResult(
            id: result.id,
            name: result.name,
            x: request.x,
            z: request.z,
            settings: request.settings
        )
    }
}

struct BiomeQueryValidation {
    static func parseSeed(_ value: String) throws -> Int64 {
        guard let seed = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw BiomeQueryViewModel.QueryError.invalidSeed
        }
        return seed
    }

    static func parseCoordinate(_ value: String) throws -> Int32 {
        guard let coordinate = Int32(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw BiomeQueryViewModel.QueryError.invalidCoordinate
        }
        return coordinate
    }
}
