//
//  SwiftBiomesTests.swift
//  SwiftBiomesTests
//
//  Created by Christopher Lloyd on 2026.07.05.
//

import Testing
import AppKit
import CubiomesCore
@testable import SwiftBiomes

struct SwiftBiomesTests {

    @Test func fixedSeedCoordinateUsesCubiomesCore() throws {
        let service = CubiomesBiomeService()
        let result = try service.biome(
            for: BiomeQueryRequest(settings: .sample, x: 0, z: 0)
        )

        #expect(result.id == 14)
        #expect(result.name == "mushroom_fields")
    }

    @Test @MainActor func viewModelPublishesQueryResult() async throws {
        let viewModel = BiomeQueryViewModel(service: StubBiomeService(name: "plains", id: 1))
        viewModel.settings.seed = 262
        viewModel.x = 8
        viewModel.z = -4

        await withCheckedContinuation { continuation in
            viewModel.onChange = { model in
                if case .result(let result) = model.state {
                    #expect(result.name == "plains")
                    #expect(result.x == 8)
                    #expect(result.z == -4)
                    continuation.resume()
                }
            }

            viewModel.submitQuery()
        }
    }

    @Test func mapRendererProducesTileImage() {
        let renderer = BiomeMapRenderer(service: StubBiomeService(name: "mushroom_fields", id: 14))
        let key = BiomeMapTileKey(
            settings: .sample,
            tileX: 0,
            tileZ: 0,
            tileWorldSize: 16,
            pixelSize: 8,
            sampleScale: 2
        )

        let tile = renderer.renderTile(key: key)

        #expect(tile.originX == 0)
        #expect(tile.originZ == 0)
        #expect(tile.image.size == CGSize(width: 8, height: 8))
    }

    @Test func batchMapRendererProducesCubiomesTileImage() {
        let renderer = BiomeMapRenderer()
        let key = BiomeMapTileKey(
            settings: .sample,
            tileX: 0,
            tileZ: 0,
            tileWorldSize: 16,
            pixelSize: 16,
            sampleScale: 1
        )

        let tile = renderer.renderTile(key: key)

        #expect(tile.originX == 0)
        #expect(tile.originZ == 0)
        #expect(tile.image.size == CGSize(width: 16, height: 16))
    }

    @Test func mapRendererKeepsTopToBottomWorldZOrder() throws {
        let renderer = BiomeMapRenderer(service: ZBandBiomeService())
        let key = BiomeMapTileKey(
            settings: .sample,
            tileX: 0,
            tileZ: 0,
            tileWorldSize: 16,
            pixelSize: 16,
            sampleScale: 1
        )

        let tile = renderer.renderTile(key: key)
        let pixels = try rgbaPixels(from: tile.image)
        let topLeft = pixels.rgbaAt(x: 0, y: 0)
        let bottomLeft = pixels.rgbaAt(x: 0, y: 15)

        #expect(topLeft.blue > topLeft.red)
        #expect(bottomLeft.red > bottomLeft.blue)
    }

    @Test func mapRendererUsesCoarserScalesWhenZoomedFarOut() {
        #expect(BiomeMapRenderer.sampleScale(for: 2.0) == 1)
        #expect(BiomeMapRenderer.sampleScale(for: 0.2) == 4)
        #expect(BiomeMapRenderer.sampleScale(for: 0.05) == 16)
        #expect(BiomeMapRenderer.sampleScale(for: 0.01) == 64)
        #expect(BiomeMapRenderer.sampleScale(for: 0.005) == 256)
        #expect(BiomeMapRenderer.sampleScale(for: 0.002) == 256)
    }

    @Test func biomeTileCacheKeepsRecentlyUsedTiles() {
        let cache = BiomeTileCache(limit: 2)
        let first = tileKey(tileX: 0)
        let second = tileKey(tileX: 1)
        let third = tileKey(tileX: 2)
        let image = NSImage(size: CGSize(width: 1, height: 1))

        cache.insert(image, for: first)
        cache.insert(image, for: second)
        #expect(cache.image(for: first) != nil)
        cache.insert(image, for: third)

        #expect(cache.image(for: first) != nil)
        #expect(cache.image(for: second) == nil)
        #expect(cache.image(for: third) != nil)
    }

    @Test func biomeTileCacheCanHoldTheVisibleWorkingSet() {
        let cache = BiomeTileCache(limit: 2)
        let keys = (0..<6).map { tileKey(tileX: $0) }
        let image = NSImage(size: CGSize(width: 1, height: 1))

        cache.ensureCapacity(atLeast: keys.count)
        for key in keys {
            cache.insert(image, for: key)
        }

        #expect(keys.allSatisfy { cache.image(for: $0) != nil })
    }

    @Test func cubiomesBiomeGridKeepsExpectedRowOrder() throws {
        let service = CubiomesBiomeService()
        let request = BiomeGridDisplayRequest(
            settings: .sample,
            originX: 0,
            originZ: 0,
            width: 2,
            height: 2,
            scale: 1,
            y: 63
        )

        let result = try service.biomeGrid(for: request)
        let originID = try service.biome(for: .init(settings: .sample, x: 0, z: 0)).id
        let eastID = try service.biome(for: .init(settings: .sample, x: 1, z: 0)).id
        let southID = try service.biome(for: .init(settings: .sample, x: 0, z: 1)).id
        let southEastID = try service.biome(for: .init(settings: .sample, x: 1, z: 1)).id

        #expect(result.ids.count == 4)
        #expect(result.ids[0] == originID)
        #expect(result.ids[1] == eastID)
        #expect(result.ids[2] == southID)
        #expect(result.ids[3] == southEastID)
    }

    @Test func structureOverlayProviderReturnsRealQueryStatus() {
        let provider = CubiomesStructureOverlayProvider()
        let result = provider.points(
            for: .sample,
            visibleRect: BiomeMapVisibleRect(minX: -4096, minZ: -4096, maxX: 4096, maxZ: 4096),
            types: Set(StructureOverlayType.allCases)
        )

        switch result.status {
        case .loaded(let count):
            #expect(count == result.points.count)
            #expect(result.points.allSatisfy { $0.label.isEmpty == false })
            #expect(result.points.allSatisfy { $0.isViable })
        case .empty:
            #expect(result.points.isEmpty)
        case .failed(let message):
            Issue.record("Structure query failed: \(message)")
        default:
            Issue.record("Unexpected structure status: \(result.status)")
        }
    }

    @Test func structureOverlayProviderHidesNonViableCandidates() {
        let provider = CubiomesStructureOverlayProvider()
        let result = provider.points(
            for: .sample,
            visibleRect: BiomeMapVisibleRect(minX: -8192, minZ: -8192, maxX: 8192, maxZ: 8192),
            types: [.village, .desertPyramid]
        )

        #expect(result.points.allSatisfy { $0.isViable })
    }

    @Test func structureOverlayProviderReturnsOnlySelectedTypes() {
        let provider = CubiomesStructureOverlayProvider()
        let result = provider.points(
            for: .sample,
            visibleRect: BiomeMapVisibleRect(minX: -8192, minZ: -8192, maxX: 8192, maxZ: 8192),
            types: [.village]
        )

        #expect(result.points.allSatisfy { $0.type == .village })
    }

    @Test func structureOverlayStrongholdsMatchCoreResults() throws {
        let rect = BiomeMapVisibleRect(minX: -8192, minZ: -8192, maxX: 8192, maxZ: 8192)
        let provider = CubiomesStructureOverlayProvider()
        let result = provider.points(for: .sample, visibleRect: rect, types: [.stronghold])
        let expected = try CubiomesCore.structures(
            version: WorldSettings.sample.version.version,
            seed: WorldSettings.sample.seed,
            dimension: WorldSettings.sample.dimension.dimension,
            types: [.stronghold],
            rect: StructureRect(minX: rect.minX, minZ: rect.minZ, maxX: rect.maxX, maxZ: rect.maxZ)
        )

        let actualCoordinates = result.points.map { "\($0.x),\($0.z)" }
        let expectedCoordinates = expected.map { "\($0.blockX),\($0.blockZ)" }
        #expect(actualCoordinates == expectedCoordinates)
        #expect(result.points.allSatisfy { $0.type == .stronghold && $0.isViable })
    }

    @Test func structureOverlayCacheKeyIncludesDimension() {
        var netherSettings = WorldSettings.sample
        netherSettings.dimension = .nether
        let rect = BiomeMapVisibleRect(minX: -128, minZ: -128, maxX: 128, maxZ: 128)

        let overworldKey = StructureOverlayCacheKey(settings: .sample, rect: rect, types: [.village])
        let netherKey = StructureOverlayCacheKey(settings: netherSettings, rect: rect, types: [.village])

        #expect(overworldKey.cacheKey != netherKey.cacheKey)
    }

    @Test func structureOverlayCacheKeyIncludesSelectedTypes() {
        let rect = BiomeMapVisibleRect(minX: -128, minZ: -128, maxX: 128, maxZ: 128)

        let villageKey = StructureOverlayCacheKey(settings: .sample, rect: rect, types: [.village])
        let monumentKey = StructureOverlayCacheKey(settings: .sample, rect: rect, types: [.monument])

        #expect(villageKey.cacheKey != monumentKey.cacheKey)
    }

    @Test func structureOverlayCacheEntryReusesItsPaddedCoverage() {
        let types: Set<StructureOverlayType> = [.village, .monument]
        let coverage = BiomeMapVisibleRect(minX: -120, minZ: -120, maxX: 120, maxZ: 120)
        let entry = StructureOverlayCacheEntry(
            identity: StructureOverlayCacheIdentity(settings: .sample, types: types),
            coverage: coverage,
            result: StructureOverlayResult(points: [], status: .empty)
        )

        #expect(entry.contains(
            settings: .sample,
            types: types,
            visibleRect: BiomeMapVisibleRect(minX: -100, minZ: -100, maxX: 100, maxZ: 100)
        ))
        #expect(!entry.contains(
            settings: .sample,
            types: types,
            visibleRect: BiomeMapVisibleRect(minX: -121, minZ: -100, maxX: 100, maxZ: 100)
        ))
        #expect(!entry.contains(
            settings: .sample,
            types: [.village],
            visibleRect: BiomeMapVisibleRect(minX: -100, minZ: -100, maxX: 100, maxZ: 100)
        ))
    }

    @Test func structureOverlayProviderHonorsEmptyTypeSelection() {
        let provider = CubiomesStructureOverlayProvider()
        let result = provider.points(
            for: .sample,
            visibleRect: BiomeMapVisibleRect(minX: -4096, minZ: -4096, maxX: 4096, maxZ: 4096),
            types: []
        )

        #expect(result.points.isEmpty)
        if case .noneSelected = result.status {
            #expect(true)
        } else {
            Issue.record("Expected none selected status, got \(result.status)")
        }
    }

    @Test func structureOverlayMapsNewRemoteStructureTypes() {
        #expect(StructureOverlayType(coreType: .oceanRuin) == .oceanRuin)
        #expect(StructureOverlayType(coreType: .shipwreck) == .shipwreck)
        #expect(StructureOverlayType(coreType: .trailRuins) == .trailRuins)
        #expect(StructureOverlayType(coreType: .trialChambers) == .trialChambers)
    }

    @Test func structureTypesAreFilteredByDimension() {
        let overworld = Set(StructureOverlayType.available(in: .overworld))
        let nether = Set(StructureOverlayType.available(in: .nether))
        let end = Set(StructureOverlayType.available(in: .end))

        #expect(nether == [.netherRuinedPortal, .fortress, .bastion])
        #expect(end == [.endCity, .endGateway, .endIsland])
        #expect(overworld.contains(.village))
        #expect(overworld.contains(.ruinedPortal))
        #expect(!overworld.contains(.fortress))
        #expect(overworld.isDisjoint(with: nether))
        #expect(overworld.isDisjoint(with: end))
        #expect(nether.isDisjoint(with: end))
        #expect(overworld.count + nether.count + end.count == StructureOverlayType.allCases.count)
    }

    @Test func structureLoadingPublishesNonStrongholdsFirst() {
        let selected: Set<StructureOverlayType> = [.village, .monument, .stronghold]

        let progressive = StructureOverlayType.progressiveLoadingTypes(from: selected)

        #expect(progressive == [.village, .monument])
        #expect(StructureOverlayType.progressiveLoadingTypes(from: [.stronghold]).isEmpty)
        #expect(StructureOverlayType.progressiveLoadingTypes(from: [.village]).isEmpty)
    }

    @Test func worldInsightProviderUsesOverworldOnlyAnchors() {
        let provider = CubiomesWorldInsightProvider()
        let overworld = provider.snapshot(for: .init(settings: .sample, x: -1, z: -17))

        #expect(overworld.spawn != nil)
        #expect(overworld.estimatedSpawn != nil)
        #expect(overworld.firstStronghold != nil)
        #expect(overworld.currentChunkX == -1)
        #expect(overworld.currentChunkZ == -2)
        #expect(overworld.isCurrentSlimeChunk != nil)

        var netherSettings = WorldSettings.sample
        netherSettings.dimension = .nether
        let nether = provider.snapshot(for: .init(settings: netherSettings, x: -1, z: -17))

        #expect(nether.spawn == nil)
        #expect(nether.estimatedSpawn == nil)
        #expect(nether.firstStronghold == nil)
        #expect(nether.currentChunkX == -1)
        #expect(nether.currentChunkZ == -2)
        #expect(nether.isCurrentSlimeChunk == nil)
    }

    @Test func screenshotSlimeChunkSelectionUsesDifferentCoordinateThanCurrentChunk() {
        let provider = CubiomesWorldInsightProvider()
        let snapshot = provider.snapshot(for: .init(settings: .sample, x: -283, z: -68))

        #expect(snapshot.currentChunkX == -18)
        #expect(snapshot.currentChunkZ == -5)
        #expect(snapshot.isCurrentSlimeChunk == false)
        #expect(CubiomesCore.isSlimeChunk(seed: WorldSettings.sample.seed, chunkX: -20, chunkZ: -1))
    }

    @Test func slimeChunkInspectorTextIncludesSelectedChunkAndOrigin() {
        let point = StructureOverlayPoint(
            type: .slimeChunk,
            x: -320,
            z: -16,
            label: "Slime Chunk",
            isViable: true
        )

        #expect(point.inspectorText == "Slime Chunk, viable, Chunk -20, -1, origin X -320, Z -16")
    }

    @Test func validationRejectsInvalidCoordinate() {
        #expect(throws: BiomeQueryViewModel.QueryError.invalidCoordinate) {
            _ = try BiomeQueryValidation.parseCoordinate("12.5")
        }
    }

    @Test func seedFinderCatalogUsesVersionAndDimension() throws {
        let version = try #require(MinecraftVersionOption.supported.first { $0.label == "1.18" })
        let overworld = SeedFinderCatalog.biomes(for: version, dimension: .overworld)
        let nether = SeedFinderCatalog.biomes(for: version, dimension: .nether)

        #expect(overworld.contains(SeedFinderBiomeOption(id: 14, name: "mushroom_fields")))
        #expect(!nether.contains { $0.id == 14 })
        #expect(overworld.map(\.title) == overworld.map(\.title).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func seedFinderChecksInclusiveRangeInNumericOrder() throws {
        let mushroomFields = SeedFinderBiomeOption(id: 14, name: "mushroom_fields")
        let request = SeedFinderRequest(
            settings: .sample,
            startSeed: 260,
            endSeed: 264,
            x: 0,
            z: 0,
            targetBiome: mushroomFields,
            maximumResults: 1
        )
        var progressEvents: [SeedFinderProgress] = []

        let results = try CubiomesSeedFinder().findSeeds(
            for: request,
            cancellationToken: CubiomesSearchCancellationToken()
        ) { progress in
            progressEvents.append(progress)
        }

        #expect(results.map(\.seed) == [262])
        #expect(progressEvents.map(\.currentSeed) == [260, 261, 262])
        #expect(progressEvents.last?.checkedSeeds == 3)
        #expect(progressEvents.last?.totalSeeds == 5)
    }

    @Test func seedFinderValidatesRangeAndFormatsQtColumns() throws {
        let biome = SeedFinderBiomeOption(id: 1, name: "plains")
        let invalid = SeedFinderRequest(
            settings: .sample,
            startSeed: 5,
            endSeed: 4,
            x: 0,
            z: 0,
            targetBiome: biome
        )

        #expect(throws: SeedFinderError.invalidRange) {
            _ = try invalid.validatedSeedCount()
        }
        #expect(try SeedFinderRequest(
            settings: .sample,
            startSeed: -1,
            endSeed: 1,
            x: 0,
            z: 0,
            targetBiome: biome
        ).validatedSeedCount() == 3)
        #expect(SeedFinderResult(seed: -1).top16Hex == "ffff")
        #expect(SeedFinderResult(seed: -1).lower48Hex == "ffffffffffff")
    }

    @Test func seedFinderStructureCatalogUsesVersionAndDimension() throws {
        let version18 = try #require(MinecraftVersionOption.supported.first { $0.label == "1.18" })
        let version19 = try #require(MinecraftVersionOption.supported.first { $0.label == "1.19" })

        let overworld18 = SeedFinderCatalog.structures(for: version18, dimension: .overworld)
        let overworld19 = SeedFinderCatalog.structures(for: version19, dimension: .overworld)
        let nether19 = SeedFinderCatalog.structures(for: version19, dimension: .nether)

        #expect(overworld18.contains(SeedFinderStructureOption(type: .village)))
        #expect(!overworld18.contains(SeedFinderStructureOption(type: .ancientCity)))
        #expect(overworld19.contains(SeedFinderStructureOption(type: .ancientCity)))
        #expect(nether19.contains(SeedFinderStructureOption(type: .fortress)))
        #expect(!nether19.contains(SeedFinderStructureOption(type: .village)))
    }

    @Test func seedFinderRequiresEveryBiomeCondition() throws {
        let service = CubiomesBiomeService()
        let origin = try service.biome(for: .init(settings: .sample, x: 0, z: 0))
        let distant = try service.biome(for: .init(settings: .sample, x: 2048, z: 2048))
        let request = SeedFinderRequest(
            settings: .sample,
            startSeed: 262,
            endSeed: 262,
            conditions: [
                .biome(.init(
                    biome: SeedFinderBiomeOption(id: origin.id, name: origin.name),
                    x: origin.x,
                    z: origin.z
                )),
                .biome(.init(
                    biome: SeedFinderBiomeOption(id: distant.id, name: distant.name),
                    x: distant.x,
                    z: distant.z
                ))
            ]
        )

        let results = try CubiomesSeedFinder().findSeeds(
            for: request,
            cancellationToken: CubiomesSearchCancellationToken()
        ) { _ in }

        #expect(results.map(\.seed) == [262])
        #expect(try request.queryConditions().count == 2)
    }

    @Test func seedFinderMatchesViableStructureInsideArea() throws {
        let searchRect = StructureRect(minX: -8192, minZ: -8192, maxX: 8192, maxZ: 8192)
        let locations = try CubiomesCore.structures(
            version: WorldSettings.sample.version.version,
            seed: WorldSettings.sample.seed,
            dimension: WorldSettings.sample.dimension.dimension,
            types: [.village],
            rect: searchRect
        )
        let viableLocations = locations.filter { $0.isViable }
        let village = try #require(viableLocations.first)
        let request = SeedFinderRequest(
            settings: .sample,
            startSeed: 262,
            endSeed: 262,
            conditions: [
                .structure(SeedFinderStructureCondition(
                    structure: SeedFinderStructureOption(type: .village),
                    centerX: village.blockX,
                    centerZ: village.blockZ,
                    radius: 32
                ))
            ]
        )

        let results = try CubiomesSeedFinder().findSeeds(
            for: request,
            cancellationToken: CubiomesSearchCancellationToken()
        ) { _ in }

        #expect(results.map(\.seed) == [262])
    }

    @Test func seedFinderValidatesConditionListAndStructureArea() {
        let empty = SeedFinderRequest(
            settings: .sample,
            startSeed: 0,
            endSeed: 1,
            conditions: []
        )
        let invalidRadius = SeedFinderRequest(
            settings: .sample,
            startSeed: 0,
            endSeed: 1,
            conditions: [
                .structure(SeedFinderStructureCondition(
                    structure: SeedFinderStructureOption(type: .village),
                    centerX: 0,
                    centerZ: 0,
                    radius: 0
                ))
            ]
        )

        #expect(throws: SeedFinderError.missingConditions) {
            _ = try empty.validatedSeedCount()
        }
        #expect(throws: SeedFinderError.invalidStructureRadius) {
            _ = try invalidRadius.validatedSeedCount()
        }
    }

}

private func tileKey(tileX: Int) -> BiomeMapTileKey {
    BiomeMapTileKey(
        settings: .sample,
        tileX: tileX,
        tileZ: 0,
        tileWorldSize: 128,
        pixelSize: 128,
        sampleScale: 1
    )
}

private struct StubBiomeService: BiomeProviding {
    let name: String
    let id: Int32

    func biome(for request: BiomeQueryRequest) throws -> BiomeDisplayResult {
        BiomeDisplayResult(
            id: id,
            name: name,
            x: request.x,
            z: request.z,
            settings: request.settings
        )
    }
}

private struct ZBandBiomeService: BiomeProviding {
    func biome(for request: BiomeQueryRequest) throws -> BiomeDisplayResult {
        let name = request.z < 8 ? "ocean" : "desert"
        return BiomeDisplayResult(
            id: request.z < 8 ? 0 : 2,
            name: name,
            x: request.x,
            z: request.z,
            settings: request.settings
        )
    }
}

private struct RGBAPixels {
    let bytes: [UInt8]
    let width: Int
    let bytesPerRow: Int

    func rgbaAt(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let offset = y * bytesPerRow + x * 4
        return (
            bytes[offset],
            bytes[offset + 1],
            bytes[offset + 2],
            bytes[offset + 3]
        )
    }
}

private func rgbaPixels(from image: NSImage) throws -> RGBAPixels {
    var proposedRect = NSRect(origin: .zero, size: image.size)
    let cgImage = try #require(image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil))
    let dataReference = try #require(cgImage.dataProvider?.data)
    let data = dataReference as Data
    return RGBAPixels(
        bytes: Array(data),
        width: cgImage.width,
        bytesPerRow: cgImage.bytesPerRow
    )
}
