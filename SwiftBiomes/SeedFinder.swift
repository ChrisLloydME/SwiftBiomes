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
}

struct SeedFinderRequest: Equatable, Sendable {
    nonisolated static let maximumSeedCount = 1_000_000

    let settings: WorldSettings
    let startSeed: Int64
    let endSeed: Int64
    let x: Int32
    let z: Int32
    let y: Int32
    let targetBiome: SeedFinderBiomeOption
    let maximumResults: Int

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
        self.settings = settings
        self.startSeed = startSeed
        self.endSeed = endSeed
        self.x = x
        self.z = z
        self.y = y
        self.targetBiome = targetBiome
        self.maximumResults = maximumResults
    }

    nonisolated func validatedSeedCount() throws -> Int {
        guard endSeed >= startSeed else {
            throw SeedFinderError.invalidRange
        }
        guard maximumResults > 0 else {
            throw SeedFinderError.invalidMaximumResults
        }

        let (distance, overflow) = endSeed.subtractingReportingOverflow(startSeed)
        guard !overflow, distance < Int64(Self.maximumSeedCount) else {
            throw SeedFinderError.rangeTooLarge(maximum: Self.maximumSeedCount)
        }
        return Int(distance) + 1
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

    var message: String {
        switch self {
        case .invalidRange:
            return "The end seed must be greater than or equal to the start seed."
        case .rangeTooLarge(let maximum):
            return "Search up to \(maximum.formatted()) seeds at a time in this initial version."
        case .invalidMaximumResults:
            return "The number of results must be at least one."
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
                    conditions: [
                        .biomeAt(
                            relativeX: request.x,
                            relativeZ: request.z,
                            y: request.y,
                            allowedBiomeIDs: [request.targetBiome.id]
                        )
                    ],
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
