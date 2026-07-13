import AppKit
import CubiomesCore
import os

private let mapLoadingSignposter = OSSignposter(
    subsystem: "com.LloydME.SwiftBiomes",
    category: "MapLoading"
)

struct BiomeMapTileKey: Hashable, Sendable {
    let settings: WorldSettings
    let tileX: Int
    let tileZ: Int
    let tileWorldSize: Int
    let pixelSize: Int
    let sampleScale: Int

    var cacheKey: String {
        "\(settings.seed)-\(settings.version.label)-\(settings.dimension.rawValue)-\(tileX)-\(tileZ)-\(tileWorldSize)-\(pixelSize)-\(sampleScale)"
    }
}

struct BiomeMapTile: Sendable {
    let key: BiomeMapTileKey
    let originX: Int
    let originZ: Int
    let worldSize: Int
    let image: NSImage
}

struct BiomeMapVisibleRect: Equatable, Sendable {
    let minX: Int32
    let minZ: Int32
    let maxX: Int32
    let maxZ: Int32

    func contains(_ other: BiomeMapVisibleRect) -> Bool {
        minX <= other.minX && minZ <= other.minZ &&
            maxX >= other.maxX && maxZ >= other.maxZ
    }
}

final class BiomeTileCache {
    private struct Entry {
        let image: NSImage
        var accessOrder: UInt64
    }

    private let limit: Int
    private var images: [BiomeMapTileKey: Entry] = [:]
    private var nextAccessOrder: UInt64 = 0
    private let lock = NSLock()

    init(limit: Int = 128) {
        self.limit = limit
    }

    func image(for key: BiomeMapTileKey) -> NSImage? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard var entry = images[key] else {
            return nil
        }

        entry.accessOrder = nextAccess()
        images[key] = entry
        return entry.image
    }

    func insert(_ image: NSImage, for key: BiomeMapTileKey) {
        lock.lock()
        defer {
            lock.unlock()
        }

        images[key] = Entry(image: image, accessOrder: nextAccess())
        trimIfNeeded()
    }

    func removeAll() {
        lock.lock()
        images.removeAll()
        nextAccessOrder = 0
        lock.unlock()
    }

    private func nextAccess() -> UInt64 {
        nextAccessOrder &+= 1
        return nextAccessOrder
    }

    private func trimIfNeeded() {
        while images.count > limit,
              let oldest = images.min(by: { $0.value.accessOrder < $1.value.accessOrder })?.key {
            images.removeValue(forKey: oldest)
        }
    }
}

final class BiomeMapRenderer {
    static let tilePixelSize = 128
    static let recommendedWorkerCount = min(
        8,
        max(1, ProcessInfo.processInfo.activeProcessorCount)
    )

    private let service: any BiomeProviding

    init(service: any BiomeProviding = CubiomesBiomeService()) {
        self.service = service
    }

    func renderTile(key: BiomeMapTileKey) -> BiomeMapTile {
        let signpostState = mapLoadingSignposter.beginInterval("Render Tile")
        defer {
            mapLoadingSignposter.endInterval("Render Tile", signpostState)
        }

        let originX = key.tileX * key.tileWorldSize
        let originZ = key.tileZ * key.tileWorldSize
        if let tile = renderBatchTile(key: key, originX: originX, originZ: originZ) {
            return tile
        }

        return renderFallbackTile(key: key, originX: originX, originZ: originZ)
    }

    static func sampleScale(for pixelsPerBlock: Double) -> Int {
        if pixelsPerBlock > 0.5 {
            return 1
        }
        if pixelsPerBlock > 0.125 {
            return 4
        }
        if pixelsPerBlock > 0.03125 {
            return 16
        }
        if pixelsPerBlock > 0.0078125 {
            return 64
        }
        if pixelsPerBlock > 0.00390625 {
            return 256
        }
        return 256
    }

    static func fallbackScales(for activeScale: Int) -> [Int] {
        var scales: [Int] = []
        var scale = activeScale * 4
        while scale <= 256 {
            scales.append(scale)
            scale *= 4
        }
        return scales.reversed()
    }

    static func shouldRequestFallbackScale(_ scale: Int, for activeScale: Int) -> Bool {
        scale == activeScale * 4
    }

    static func tileWorldSize(for pixelsPerBlock: Double) -> Int {
        tilePixelSize * sampleScale(for: pixelsPerBlock)
    }

    static func tileWorldSize(forSampleScale sampleScale: Int) -> Int {
        tilePixelSize * sampleScale
    }

    private func renderBatchTile(key: BiomeMapTileKey, originX: Int, originZ: Int) -> BiomeMapTile? {
        let request = BiomeGridDisplayRequest(
            settings: key.settings,
            originX: Int32(clamping: originX / key.sampleScale),
            originZ: Int32(clamping: originZ / key.sampleScale),
            width: key.pixelSize,
            height: key.pixelSize,
            scale: key.sampleScale,
            y: 63
        )

        guard let grid = try? service.biomeGrid(for: request), grid.ids.count == key.pixelSize * key.pixelSize else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: key.pixelSize * key.pixelSize * 4)
        for py in 0..<key.pixelSize {
            for px in 0..<key.pixelSize {
                let biomeID = grid.ids[py * key.pixelSize + px]
                let rgba = BiomePalette.rgba(forBiomeID: biomeID)
                let offset = (py * key.pixelSize + px) * 4
                pixels[offset] = rgba.red
                pixels[offset + 1] = rgba.green
                pixels[offset + 2] = rgba.blue
                pixels[offset + 3] = rgba.alpha
            }
        }

        return makeTile(key: key, originX: originX, originZ: originZ, pixels: pixels)
    }

    private func renderFallbackTile(key: BiomeMapTileKey, originX: Int, originZ: Int) -> BiomeMapTile {
        var pixels = [UInt8](repeating: 0, count: key.pixelSize * key.pixelSize * 4)

        for px in 0..<key.pixelSize {
            for py in 0..<key.pixelSize {
                let blockX = originX + Int((Double(px) / Double(key.pixelSize)) * Double(key.tileWorldSize))
                let blockZ = originZ + Int((Double(py) / Double(key.pixelSize)) * Double(key.tileWorldSize))
                let request = BiomeQueryRequest(
                    settings: key.settings,
                    x: Int32(clamping: blockX),
                    z: Int32(clamping: blockZ)
                )

                let rgba: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)
                if let biome = try? service.biome(for: request) {
                    rgba = BiomePalette.rgba(for: biome.name)
                } else {
                    rgba = (118, 118, 128, 255)
                }

                let offset = (py * key.pixelSize + px) * 4
                pixels[offset] = rgba.red
                pixels[offset + 1] = rgba.green
                pixels[offset + 2] = rgba.blue
                pixels[offset + 3] = rgba.alpha
            }
        }

        return makeTile(key: key, originX: originX, originZ: originZ, pixels: pixels)
    }

    private func makeTile(key: BiomeMapTileKey, originX: Int, originZ: Int, pixels: [UInt8]) -> BiomeMapTile {
        let data = Data(pixels)
        let provider = CGDataProvider(data: data as CFData)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgImage = CGImage(
            width: key.pixelSize,
            height: key.pixelSize,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: key.pixelSize * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        let image = NSImage(cgImage: cgImage, size: NSSize(width: key.pixelSize, height: key.pixelSize))

        return BiomeMapTile(
            key: key,
            originX: originX,
            originZ: originZ,
            worldSize: key.tileWorldSize,
            image: image
        )
    }
}
