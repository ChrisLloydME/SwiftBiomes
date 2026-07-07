import Foundation
import CubiomesCore

struct WorldInsightPosition: Equatable, Sendable {
    let x: Int32
    let z: Int32

    var displayText: String {
        "X \(x), Z \(z)"
    }
}

struct WorldInsightSnapshot: Equatable, Sendable {
    let request: BiomeQueryRequest
    let spawn: WorldInsightPosition?
    let estimatedSpawn: WorldInsightPosition?
    let firstStronghold: WorldInsightPosition?
    let currentChunkX: Int32
    let currentChunkZ: Int32
    let isCurrentSlimeChunk: Bool?
}

protocol WorldInsightProviding: Sendable {
    nonisolated func snapshot(for request: BiomeQueryRequest) -> WorldInsightSnapshot
}

struct CubiomesWorldInsightProvider: WorldInsightProviding {
    nonisolated func snapshot(for request: BiomeQueryRequest) -> WorldInsightSnapshot {
        let chunkX = floorDiv(request.x, 16)
        let chunkZ = floorDiv(request.z, 16)
        guard request.settings.dimension == .overworld else {
            return WorldInsightSnapshot(
                request: request,
                spawn: nil,
                estimatedSpawn: nil,
                firstStronghold: nil,
                currentChunkX: chunkX,
                currentChunkZ: chunkZ,
                isCurrentSlimeChunk: nil
            )
        }

        let spawn = CubiomesCore.spawn(version: request.settings.version.version, seed: request.settings.seed)
        let estimatedSpawn = CubiomesCore.estimatedSpawn(version: request.settings.version.version, seed: request.settings.seed)
        let stronghold = CubiomesCore.firstStrongholdApproximation(version: request.settings.version.version, seed: request.settings.seed)
        let isSlimeChunk = CubiomesCore.isSlimeChunk(seed: request.settings.seed, chunkX: chunkX, chunkZ: chunkZ)

        return WorldInsightSnapshot(
            request: request,
            spawn: WorldInsightPosition(x: spawn.x, z: spawn.z),
            estimatedSpawn: WorldInsightPosition(x: estimatedSpawn.x, z: estimatedSpawn.z),
            firstStronghold: WorldInsightPosition(x: stronghold.x, z: stronghold.z),
            currentChunkX: chunkX,
            currentChunkZ: chunkZ,
            isCurrentSlimeChunk: isSlimeChunk
        )
    }

    private nonisolated func floorDiv(_ value: Int32, _ divisor: Int32) -> Int32 {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }
}
