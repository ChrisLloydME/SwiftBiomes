import AppKit

final class BiomeMapView: NSView {
    var settings: WorldSettings = .sample {
        didSet {
            if oldValue != settings {
                reloadMap()
            }
        }
    }

    var overlayEnabled = false {
        didSet {
            if overlayEnabled {
                requestVisibleStructures()
            } else {
                structureGeneration += 1
                pendingStructureKey = nil
                visibleStructures = []
                selectedStructure = nil
                structureStatus = .disabled
                structureQueue.cancelAllOperations()
                onStructureOverlayStatusChanged?(structureStatus)
            }
            needsDisplay = true
        }
    }

    var onCoordinateSelected: ((Int32, Int32) -> Void)?
    var onVisibleCoordinateChanged: ((Int32, Int32) -> Void)?
    var onStructureOverlayStatusChanged: ((StructureOverlayStatus) -> Void)?

    private let renderer = BiomeMapRenderer()
    private let cache = BiomeTileCache(limit: 512)
    private let renderQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SwiftBiomes.TileRenderer"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private let structureProvider: any StructureOverlayProviding = CubiomesStructureOverlayProvider()
    private let structureQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SwiftBiomes.StructureOverlay"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var pendingKeys = Set<String>()
    private var pendingStructureKey: String?
    private var visibleStructures: [StructureOverlayPoint] = []
    private var selectedStructure: StructureOverlayPoint?
    private var structureStatus: StructureOverlayStatus = .disabled
    private var centerX: Double = 0
    private var centerZ: Double = 0
    private var pixelsPerBlock: Double = 2.0
    private let minimumPixelsPerBlock = 1.0 / 512.0
    private let maximumPixelsPerBlock = 12.0
    private var dragStartPoint: NSPoint?
    private var dragStartCenter: CGPoint = .zero
    private var renderGeneration = 0
    private var structureGeneration = 0

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        postsFrameChangedNotifications = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        renderQueue.cancelAllOperations()
        structureQueue.cancelAllOperations()
    }

    func centerOnOrigin() {
        centerX = 0
        centerZ = 0
        needsDisplay = true
        notifyCenter()
    }

    func zoomIn() {
        setZoom(pixelsPerBlock * 1.35)
    }

    func zoomOut() {
        setZoom(pixelsPerBlock / 1.35)
    }

    func reloadMap() {
        renderGeneration += 1
        structureGeneration += 1
        pendingKeys.removeAll()
        pendingStructureKey = nil
        visibleStructures = []
        selectedStructure = nil
        renderQueue.cancelAllOperations()
        structureQueue.cancelAllOperations()
        cache.removeAll()
        if overlayEnabled {
            requestVisibleStructures()
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        drawTiles()
        drawGrid()
        drawCrosshair()
        drawStructureOverlay()
        drawOverlayNotice()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartCenter = CGPoint(x: centerX, y: centerZ)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartPoint else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        centerX = dragStartCenter.x - Double(point.x - start.x) / pixelsPerBlock
        centerZ = dragStartCenter.y - Double(point.y - start.y) / pixelsPerBlock
        selectedStructure = nil
        needsDisplay = true
        notifyCenter()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if overlayEnabled, let structure = nearestStructure(to: point, maximumDistance: 12) {
            selectedStructure = structure
            structureStatus = .selected(structure)
            onStructureOverlayStatusChanged?(structureStatus)
            needsDisplay = true
            dragStartPoint = nil
            return
        }
        let world = worldCoordinate(at: point)
        onCoordinateSelected?(world.x, world.z)
        dragStartPoint = nil
    }

    override func scrollWheel(with event: NSEvent) {
        centerX -= Double(event.scrollingDeltaX) / pixelsPerBlock
        centerZ -= Double(event.scrollingDeltaY) / pixelsPerBlock
        selectedStructure = nil
        needsDisplay = true
        notifyCenter()
    }

    override func magnify(with event: NSEvent) {
        setZoom(pixelsPerBlock * (1.0 + Double(event.magnification)))
    }

    private func setZoom(_ value: Double) {
        let previousScale = BiomeMapRenderer.sampleScale(for: pixelsPerBlock)
        pixelsPerBlock = min(max(value, minimumPixelsPerBlock), maximumPixelsPerBlock)
        let nextScale = BiomeMapRenderer.sampleScale(for: pixelsPerBlock)
        if previousScale != nextScale {
            cancelPendingRenderRequests()
        }
        selectedStructure = nil
        needsDisplay = true
    }

    private func cancelPendingRenderRequests() {
        pendingKeys.removeAll()
        renderQueue.cancelAllOperations()
    }

    private func drawTiles() {
        let activeScale = BiomeMapRenderer.sampleScale(for: pixelsPerBlock)
        let fallbackScales = fallbackScales(for: activeScale)

        for scale in fallbackScales {
            drawTileLayer(sampleScale: scale, paddingRatio: 0.08, fillMissing: false)
        }
        drawTileLayer(sampleScale: activeScale, paddingRatio: activeScale >= 256 ? 0.12 : 0.35, fillMissing: fallbackScales.isEmpty)
    }

    private func fallbackScales(for activeScale: Int) -> [Int] {
        var scales: [Int] = []
        var scale = activeScale * 4
        while scale <= 256 {
            scales.append(scale)
            scale *= 4
        }
        return scales.reversed()
    }

    private func drawTileLayer(sampleScale: Int, paddingRatio: Double, fillMissing: Bool) {
        let tileWorldSize = BiomeMapRenderer.tileWorldSize(forSampleScale: sampleScale)
        let pixelSize = BiomeMapRenderer.tilePixelSize
        let visible = visibleWorldRect(paddingRatio: paddingRatio)
        let minTileX = floorDiv(Int(visible.minX), tileWorldSize)
        let maxTileX = floorDiv(Int(visible.maxX), tileWorldSize)
        let minTileZ = floorDiv(Int(visible.minZ), tileWorldSize)
        let maxTileZ = floorDiv(Int(visible.maxZ), tileWorldSize)
        let visibleBounds = bounds.insetBy(dx: -64, dy: -64)

        var tiles: [(key: BiomeMapTileKey, rect: NSRect, distance: Double)] = []

        for tileX in minTileX...maxTileX {
            for tileZ in minTileZ...maxTileZ {
                let key = BiomeMapTileKey(
                    settings: settings,
                    tileX: tileX,
                    tileZ: tileZ,
                    tileWorldSize: tileWorldSize,
                    pixelSize: pixelSize,
                    sampleScale: sampleScale
                )
                let originX = tileX * tileWorldSize
                let originZ = tileZ * tileWorldSize
                let rect = rectForTile(originX: originX, originZ: originZ, worldSize: tileWorldSize)
                let distance = hypot(Double(originX) + Double(tileWorldSize) / 2.0 - centerX, Double(originZ) + Double(tileWorldSize) / 2.0 - centerZ)
                tiles.append((key, rect, distance))
            }
        }

        for tile in tiles.sorted(by: { $0.distance < $1.distance }) {
            if let image = cache.image(for: tile.key) {
                if tile.rect.intersects(visibleBounds) {
                    image.draw(in: tile.rect)
                }
            } else {
                if fillMissing, tile.rect.intersects(bounds) {
                    NSColor.controlBackgroundColor.setFill()
                    tile.rect.fill()
                }
                requestTile(for: tile.key)
            }
        }
    }

    private func requestTile(for key: BiomeMapTileKey) {
        guard !pendingKeys.contains(key.cacheKey) else {
            return
        }

        pendingKeys.insert(key.cacheKey)
        let generation = renderGeneration
        let renderer = renderer

        renderQueue.addOperation { [weak self] in
            let tile = renderer.renderTile(key: key)
            OperationQueue.main.addOperation {
                guard let self, generation == self.renderGeneration else {
                    return
                }

                self.pendingKeys.remove(key.cacheKey)
                self.cache.insert(tile.image, for: key)
                self.needsDisplay = true
            }
        }
    }

    private func drawGrid() {
        let visible = visibleWorldRect()
        let step = gridStep()
        let path = NSBezierPath()
        path.lineWidth = 1

        var x = floorDiv(Int(visible.minX), step) * step
        while x <= Int(visible.maxX) {
            let sx = bounds.midX + (Double(x) - centerX) * pixelsPerBlock
            path.move(to: NSPoint(x: sx, y: bounds.minY))
            path.line(to: NSPoint(x: sx, y: bounds.maxY))
            x += step
        }

        var z = floorDiv(Int(visible.minZ), step) * step
        while z <= Int(visible.maxZ) {
            let sy = bounds.midY + (Double(z) - centerZ) * pixelsPerBlock
            path.move(to: NSPoint(x: bounds.minX, y: sy))
            path.line(to: NSPoint(x: bounds.maxX, y: sy))
            z += step
        }

        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        path.stroke()
    }

    private func drawCrosshair() {
        let origin = pointForWorld(x: 0, z: 0)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: origin.x - 8, y: origin.y))
        path.line(to: NSPoint(x: origin.x + 8, y: origin.y))
        path.move(to: NSPoint(x: origin.x, y: origin.y - 8))
        path.line(to: NSPoint(x: origin.x, y: origin.y + 8))
        path.lineWidth = 1.5
        NSColor.labelColor.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }

    private func drawOverlayNotice() {
        guard overlayEnabled else {
            return
        }

        requestVisibleStructures()

        let text: String
        switch structureStatus {
        case .disabled:
            return
        case .loading:
            text = "Loading structures..."
        case .loaded(let count):
            text = "\(count) structures in view"
        case .empty:
            text = "No structures in view"
        case .selected(let point):
            text = "\(point.label) at X \(point.x), Z \(point.z)"
        case .failed(let message):
            text = message
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(x: bounds.maxX - size.width - 16, y: bounds.minY + 12, width: size.width, height: size.height)
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawStructureOverlay() {
        guard overlayEnabled else {
            return
        }

        for point in visibleStructures {
            let screenPoint = pointForWorld(x: Double(point.x), z: Double(point.z))
            let selected = point == selectedStructure
            let radius: CGFloat = selected ? 6 : 4
            let rect = NSRect(
                x: screenPoint.x - radius,
                y: screenPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let path = NSBezierPath(ovalIn: rect)
            StructureOverlayStyle.color(for: point.type).setFill()
            path.fill()
            NSColor.windowBackgroundColor.withAlphaComponent(selected ? 0.95 : 0.75).setStroke()
            path.lineWidth = selected ? 2 : 1
            path.stroke()
        }
    }

    private func requestVisibleStructures() {
        guard overlayEnabled else {
            return
        }

        let visible = visibleWorldRect(paddingRatio: 0.2)
        let key = StructureOverlayCacheKey(settings: settings, rect: visible)
        guard pendingStructureKey != key.cacheKey else {
            return
        }

        pendingStructureKey = key.cacheKey
        structureStatus = .loading
        onStructureOverlayStatusChanged?(structureStatus)
        let generation = structureGeneration
        let provider = structureProvider

        structureQueue.cancelAllOperations()
        structureQueue.addOperation { [weak self] in
            let result = provider.points(for: key.settings, visibleRect: key.rect)
            OperationQueue.main.addOperation {
                guard let self, generation == self.structureGeneration else {
                    return
                }

                self.visibleStructures = result.points
                self.selectedStructure = nil
                self.structureStatus = result.status
                self.onStructureOverlayStatusChanged?(result.status)
                self.needsDisplay = true
            }
        }
    }

    private func nearestStructure(to point: NSPoint, maximumDistance: CGFloat) -> StructureOverlayPoint? {
        var nearest: (point: StructureOverlayPoint, distance: CGFloat)?
        for structure in visibleStructures {
            let screenPoint = pointForWorld(x: Double(structure.x), z: Double(structure.z))
            let distance = hypot(point.x - screenPoint.x, point.y - screenPoint.y)
            if distance <= maximumDistance, nearest == nil || distance < nearest!.distance {
                nearest = (structure, distance)
            }
        }
        return nearest?.point
    }

    private func visibleWorldRect(paddingRatio: Double = 0) -> BiomeMapVisibleRect {
        let halfWidth = Double(bounds.width) / (2.0 * pixelsPerBlock)
        let halfHeight = Double(bounds.height) / (2.0 * pixelsPerBlock)
        let paddedHalfWidth = halfWidth * (1.0 + paddingRatio)
        let paddedHalfHeight = halfHeight * (1.0 + paddingRatio)
        return BiomeMapVisibleRect(
            minX: Int32(clamping: Int(centerX - paddedHalfWidth) - 2),
            minZ: Int32(clamping: Int(centerZ - paddedHalfHeight) - 2),
            maxX: Int32(clamping: Int(centerX + paddedHalfWidth) + 2),
            maxZ: Int32(clamping: Int(centerZ + paddedHalfHeight) + 2)
        )
    }

    private func rectForTile(originX: Int, originZ: Int, worldSize: Int) -> NSRect {
        let point = pointForWorld(x: Double(originX), z: Double(originZ))
        let side = Double(worldSize) * pixelsPerBlock
        return NSRect(x: point.x, y: point.y, width: side, height: side)
    }

    private func pointForWorld(x: Double, z: Double) -> NSPoint {
        NSPoint(
            x: bounds.midX + (x - centerX) * pixelsPerBlock,
            y: bounds.midY + (z - centerZ) * pixelsPerBlock
        )
    }

    private func worldCoordinate(at point: NSPoint) -> (x: Int32, z: Int32) {
        let x = centerX + Double(point.x - bounds.midX) / pixelsPerBlock
        let z = centerZ + Double(point.y - bounds.midY) / pixelsPerBlock
        return (Int32(clamping: Int(x.rounded())), Int32(clamping: Int(z.rounded())))
    }

    private func gridStep() -> Int {
        if pixelsPerBlock > 5 {
            return 16
        }
        if pixelsPerBlock > 1.5 {
            return 64
        }
        if pixelsPerBlock > 0.125 {
            return 256
        }
        if pixelsPerBlock > 0.03125 {
            return 1024
        }
        return 4096
    }

    private func floorDiv(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }

    private func notifyCenter() {
        onVisibleCoordinateChanged?(Int32(clamping: Int(centerX.rounded())), Int32(clamping: Int(centerZ.rounded())))
    }
}

private enum StructureOverlayStyle {
    static func color(for type: StructureOverlayType) -> NSColor {
        switch type {
        case .village, .outpost:
            return NSColor.systemGreen
        case .desertPyramid, .jungleTemple, .swampHut, .igloo:
            return NSColor.systemYellow
        case .monument, .treasure:
            return NSColor.systemBlue
        case .mansion, .ancientCity, .stronghold:
            return NSColor.systemPurple
        case .ruinedPortal, .fortress, .bastion:
            return NSColor.systemRed
        case .endCity:
            return NSColor.systemTeal
        case .mineshaft, .slimeChunk:
            return NSColor.systemOrange
        }
    }
}
