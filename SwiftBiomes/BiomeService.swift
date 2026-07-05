import Foundation
import CubiomesCore

protocol BiomeProviding: Sendable {
    nonisolated func biome(for request: BiomeQueryRequest) throws -> BiomeDisplayResult
    nonisolated func biomeGrid(for request: BiomeGridDisplayRequest) throws -> BiomeGridDisplayResult
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

    nonisolated func biomeGrid(for request: BiomeGridDisplayRequest) throws -> BiomeGridDisplayResult {
        let result = try CubiomesCore.biomes(
            version: request.settings.version.version,
            seed: request.settings.seed,
            dimension: request.settings.dimension.dimension,
            originX: request.originX,
            originZ: request.originZ,
            width: Int32(clamping: request.width),
            height: Int32(clamping: request.height),
            scale: Int32(clamping: request.scale),
            y: request.y
        )

        return BiomeGridDisplayResult(
            request: request,
            ids: result.ids
        )
    }
}

extension BiomeProviding {
    nonisolated func biomeGrid(for request: BiomeGridDisplayRequest) throws -> BiomeGridDisplayResult {
        var ids = [Int32]()
        ids.reserveCapacity(request.width * request.height)

        for z in 0..<request.height {
            for x in 0..<request.width {
                let sample = BiomeQueryRequest(
                    settings: request.settings,
                    x: request.originX * Int32(clamping: request.scale) + Int32(clamping: x * request.scale),
                    z: request.originZ * Int32(clamping: request.scale) + Int32(clamping: z * request.scale)
                )
                ids.append(try biome(for: sample).id)
            }
        }

        return BiomeGridDisplayResult(request: request, ids: ids)
    }
}

struct BiomeGridDisplayRequest: Equatable, Hashable, Sendable {
    let settings: WorldSettings
    let originX: Int32
    let originZ: Int32
    let width: Int
    let height: Int
    let scale: Int
    let y: Int32
}

struct BiomeGridDisplayResult: Equatable, Sendable {
    let request: BiomeGridDisplayRequest
    let ids: [Int32]
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
