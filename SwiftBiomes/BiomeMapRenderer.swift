import AppKit
import CubiomesCore

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
}

final class BiomeTileCache {
    private let limit: Int
    private var images: [String: NSImage] = [:]
    private var accessOrder: [String] = []
    private let lock = NSLock()

    init(limit: Int = 128) {
        self.limit = limit
    }

    func image(for key: BiomeMapTileKey) -> NSImage? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let image = images[key.cacheKey] else {
            return nil
        }

        markUsed(key.cacheKey)
        return image
    }

    func insert(_ image: NSImage, for key: BiomeMapTileKey) {
        lock.lock()
        defer {
            lock.unlock()
        }

        images[key.cacheKey] = image
        markUsed(key.cacheKey)
        trimIfNeeded()
    }

    func removeAll() {
        lock.lock()
        images.removeAll()
        accessOrder.removeAll()
        lock.unlock()
    }

    private func markUsed(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimIfNeeded() {
        while images.count > limit, let oldest = accessOrder.first {
            images.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
    }
}

final class BiomeMapRenderer {
    static let tilePixelSize = 128

    private let service: any BiomeProviding
    private let useBatchRenderer: Bool

    init(service: any BiomeProviding = CubiomesBiomeService()) {
        self.service = service
        self.useBatchRenderer = service is CubiomesBiomeService
    }

    func renderTile(key: BiomeMapTileKey) -> BiomeMapTile {
        let originX = key.tileX * key.tileWorldSize
        let originZ = key.tileZ * key.tileWorldSize
        if useBatchRenderer, let tile = renderBatchTile(key: key, originX: originX, originZ: originZ) {
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
        return 1024
    }

    static func tileWorldSize(for pixelsPerBlock: Double) -> Int {
        tilePixelSize * sampleScale(for: pixelsPerBlock)
    }

    static func tileWorldSize(forSampleScale sampleScale: Int) -> Int {
        tilePixelSize * sampleScale
    }

    private func renderBatchTile(key: BiomeMapTileKey, originX: Int, originZ: Int) -> BiomeMapTile? {
        let biomeIDCount = key.pixelSize * key.pixelSize
        var biomeIDs = [Int32](repeating: -1, count: biomeIDCount)

        let result = biomeIDs.withUnsafeMutableBufferPointer { buffer in
            SBBiomesGenerateBiomeIDs(
                key.settings.version.version.rawValue,
                key.settings.seed,
                key.settings.dimension.dimension.rawValue,
                Int32(clamping: key.sampleScale),
                Int32(clamping: originX / key.sampleScale),
                Int32(clamping: originZ / key.sampleScale),
                Int32(clamping: key.pixelSize),
                Int32(clamping: key.pixelSize),
                key.sampleScale > 1 ? 63 >> 2 : 63,
                buffer.baseAddress,
                Int32(clamping: biomeIDCount)
            )
        }

        guard result == 0 else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: key.pixelSize * key.pixelSize * 4)
        for py in 0..<key.pixelSize {
            for px in 0..<key.pixelSize {
                let biomeID = biomeIDs[py * key.pixelSize + px]
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
