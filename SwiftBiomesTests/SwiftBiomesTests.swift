//
//  SwiftBiomesTests.swift
//  SwiftBiomesTests
//
//  Created by Christopher Lloyd on 2026.07.05.
//

import Testing
import AppKit
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
        #expect(BiomeMapRenderer.sampleScale(for: 0.002) == 1024)
    }

    @Test func validationRejectsInvalidCoordinate() {
        #expect(throws: BiomeQueryViewModel.QueryError.invalidCoordinate) {
            _ = try BiomeQueryValidation.parseCoordinate("12.5")
        }
    }

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
