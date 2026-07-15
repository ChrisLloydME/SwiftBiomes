import Foundation
import CubiomesCore

struct SeedFinderBiomeOption: Equatable, Hashable, Sendable {
    let id: Int32
    let name: String

    var title: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum SeedFinderCatalog {
    // CubiomesCore 4.2.0 assumes biome2str is non-null, so only pass IDs that
    // cubiomes/biomes.h defines. Version and dimension filtering still comes
    // from biomeInfo below.
    private static let knownBiomeIDs: [Int32] =
        Array(0...53).map(Int32.init)
        + [127]
        + [129, 130, 131, 132, 133, 134, 140, 149, 151, 155, 156, 157, 158, 160, 161, 162, 163, 164, 165, 166, 167]
        + Array(168...175).map(Int32.init)
        + Array(177...186).map(Int32.init)

    static func biomes(for version: MinecraftVersionOption, dimension: DimensionOption) -> [SeedFinderBiomeOption] {
        knownBiomeIDs.compactMap { biomeID in
            let info = CubiomesCore.biomeInfo(version: version.version, id: biomeID)
            guard info.exists, info.dimension == dimension.dimension else {
                return nil
            }
            return SeedFinderBiomeOption(id: info.id, name: info.name)
        }
        .sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func structures(
        for version: MinecraftVersionOption,
        dimension: DimensionOption
    ) -> [SeedFinderStructureOption] {
        StructureOverlayType.available(in: dimension).compactMap { type in
            if type == .stronghold || type == .slimeChunk {
                return SeedFinderStructureOption(type: type)
            }
            guard
                let config = try? CubiomesCore.structureConfig(type: type.coreType, version: version.version),
                config.dimension == dimension.dimension
            else {
                return nil
            }
            return SeedFinderStructureOption(type: type)
        }
        .sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

struct SeedFinderStructureOption: Equatable, Hashable, Sendable {
    let type: StructureOverlayType

    var title: String { type.title }
}

struct SeedFinderBiomeCondition: Equatable, Sendable {
    let biome: SeedFinderBiomeOption
    let x: Int32
    let z: Int32
    let y: Int32

    init(biome: SeedFinderBiomeOption, x: Int32, z: Int32, y: Int32 = 63) {
        self.biome = biome
        self.x = x
        self.z = z
        self.y = y
    }
}

struct SeedFinderStructureCondition: Equatable, Sendable {
    let structure: SeedFinderStructureOption
    let centerX: Int32
    let centerZ: Int32
    let radius: Int32
}

enum SeedFinderCondition: Equatable, Sendable {
    case biome(SeedFinderBiomeCondition)
    case structure(SeedFinderStructureCondition)

    nonisolated func queryCondition() throws -> CubiomesQueryCondition {
        switch self {
        case .biome(let condition):
            return .biomeAt(
                relativeX: condition.x,
                relativeZ: condition.z,
                y: condition.y,
                allowedBiomeIDs: [condition.biome.id]
            )
        case .structure(let condition):
            guard condition.radius > 0 else {
                throw SeedFinderError.invalidStructureRadius
            }
            guard condition.radius <= SeedFinderRequest.maximumStructureRadius else {
                throw SeedFinderError.structureRadiusTooLarge(maximum: SeedFinderRequest.maximumStructureRadius)
            }

            let minX = Int64(condition.centerX) - Int64(condition.radius)
            let minZ = Int64(condition.centerZ) - Int64(condition.radius)
            let maxX = Int64(condition.centerX) + Int64(condition.radius) + 1
            let maxZ = Int64(condition.centerZ) + Int64(condition.radius) + 1
            guard
                minX >= Int64(Int32.min), minZ >= Int64(Int32.min),
                maxX <= Int64(Int32.max), maxZ <= Int64(Int32.max)
            else {
                throw SeedFinderError.structureAreaOutsideCoordinateRange
            }

            return .structureCombination(
                relativeRect: StructureRect(
                    minX: Int32(minX),
                    minZ: Int32(minZ),
                    maxX: Int32(maxX),
                    maxZ: Int32(maxZ)
                ),
                requirements: [
                    StructureCombinationRequirement(
                        type: condition.structure.type.coreType,
                        minimumCount: 1,
                        requiresViable: true
                    )
                ]
            )
        }
    }
}

struct SeedFinderRequest: Equatable, Sendable {
    nonisolated static let maximumSeedCount = 1_000_000
    // Matches the Qt reference condition editor's coordinate validator.
    nonisolated static let maximumStructureRadius: Int32 = 30_000_000

    let settings: WorldSettings
    let startSeed: Int64
    let endSeed: Int64
    let conditions: [SeedFinderCondition]
    let maximumResults: Int

    init(
        settings: WorldSettings,
        startSeed: Int64,
        endSeed: Int64,
        conditions: [SeedFinderCondition],
        maximumResults: Int = 1
    ) {
        self.settings = settings
        self.startSeed = startSeed
        self.endSeed = endSeed
        self.conditions = conditions
        self.maximumResults = maximumResults
    }

    init(
        settings: WorldSettings,
        startSeed: Int64,
        endSeed: Int64,
        x: Int32,
        z: Int32,
        y: Int32 = 63,
        targetBiome: SeedFinderBiomeOption,
        maximumResults: Int = 1
    ) {
        self.init(
            settings: settings,
            startSeed: startSeed,
            endSeed: endSeed,
            conditions: [
                .biome(SeedFinderBiomeCondition(biome: targetBiome, x: x, z: z, y: y))
            ],
            maximumResults: maximumResults
        )
    }

    nonisolated func validatedSeedCount() throws -> Int {
        guard endSeed >= startSeed else {
            throw SeedFinderError.invalidRange
        }
        guard maximumResults > 0 else {
            throw SeedFinderError.invalidMaximumResults
        }
        guard !conditions.isEmpty else {
            throw SeedFinderError.missingConditions
        }
        for condition in conditions {
            _ = try condition.queryCondition()
        }

        let (distance, overflow) = endSeed.subtractingReportingOverflow(startSeed)
        guard !overflow, distance < Int64(Self.maximumSeedCount) else {
            throw SeedFinderError.rangeTooLarge(maximum: Self.maximumSeedCount)
        }
        return Int(distance) + 1
    }

    nonisolated func queryConditions() throws -> [CubiomesQueryCondition] {
        try conditions.map { try $0.queryCondition() }
    }
}

struct SeedFinderResult: Equatable, Hashable, Sendable {
    let seed: Int64

    var top16Hex: String {
        String(format: "%04llx", UInt64(bitPattern: seed) >> 48)
    }

    var lower48Hex: String {
        String(format: "%012llx", UInt64(bitPattern: seed) & 0x0000_FFFF_FFFF_FFFF)
    }
}

struct SeedFinderProgress: Equatable, Sendable {
    let checkedSeeds: Int
    let totalSeeds: Int
    let matchedResults: Int
    let currentSeed: Int64

    var fractionCompleted: Double {
        guard totalSeeds > 0 else {
            return 0
        }
        return min(1, Double(checkedSeeds) / Double(totalSeeds))
    }
}

enum SeedFinderError: Error, Equatable {
    case invalidRange
    case rangeTooLarge(maximum: Int)
    case invalidMaximumResults
    case missingConditions
    case invalidStructureRadius
    case structureRadiusTooLarge(maximum: Int32)
    case structureAreaOutsideCoordinateRange
    case unavailableConditionTarget

    var message: String {
        switch self {
        case .invalidRange:
            return "The end seed must be greater than or equal to the start seed."
        case .rangeTooLarge(let maximum):
            return "Search up to \(maximum.formatted()) seeds at a time in this initial version."
        case .invalidMaximumResults:
            return "The number of results must be at least one."
        case .missingConditions:
            return "Add at least one biome or structure condition before searching."
        case .invalidStructureRadius:
            return "A structure search radius must be greater than zero."
        case .structureRadiusTooLarge(let maximum):
            return "Use a structure search radius of \(maximum.formatted()) blocks or less."
        case .structureAreaOutsideCoordinateRange:
            return "This structure search area is outside Minecraft's supported coordinate range."
        case .unavailableConditionTarget:
            return "Choose a biome or structure that is available for this version and dimension."
        }
    }
}

protocol SeedFinding: Sendable {
    nonisolated func findSeeds(
        for request: SeedFinderRequest,
        cancellationToken: CubiomesSearchCancellationToken,
        progress: @escaping (SeedFinderProgress) -> Void
    ) throws -> [SeedFinderResult]
}

struct CubiomesSeedFinder: SeedFinding {
    nonisolated private static let batchSize = 2_048

    nonisolated func findSeeds(
        for request: SeedFinderRequest,
        cancellationToken: CubiomesSearchCancellationToken,
        progress: @escaping (SeedFinderProgress) -> Void
    ) throws -> [SeedFinderResult] {
        let totalSeeds = try request.validatedSeedCount()
        let queryConditions = try request.queryConditions()
        var results: [SeedFinderResult] = []
        var checkedBeforeBatch = 0
        var nextSeed = request.startSeed

        while checkedBeforeBatch < totalSeeds, !cancellationToken.isCancelled {
            let count = min(Self.batchSize, totalSeeds - checkedBeforeBatch)
            var batch: [Int64] = []
            batch.reserveCapacity(count)

            for _ in 0..<count {
                batch.append(nextSeed)
                if nextSeed != request.endSeed {
                    nextSeed += 1
                }
            }

            let remainingResults = request.maximumResults - results.count
            let matches = try CubiomesCore.findSeeds(
                SeedSearchRequest(
                    version: request.settings.version.version,
                    seeds: batch,
                    dimension: request.settings.dimension.dimension,
                    conditions: queryConditions,
                    maximumResults: remainingResults
                ),
                cancellationToken: cancellationToken
            ) { batchProgress in
                guard let currentSeed = batchProgress.currentSeed else {
                    return
                }
                progress(SeedFinderProgress(
                    checkedSeeds: checkedBeforeBatch + batchProgress.checkedSeeds,
                    totalSeeds: totalSeeds,
                    matchedResults: results.count + batchProgress.matchedResults,
                    currentSeed: currentSeed
                ))
            }

            results.append(contentsOf: matches.map(SeedFinderResult.init(seed:)))
            checkedBeforeBatch += batch.count

            if results.count >= request.maximumResults {
                break
            }
        }

        return results
    }
}
