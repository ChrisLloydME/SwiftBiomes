import Foundation
import CubiomesCore
import os

private let structureLoadingSignposter = OSSignposter(
    subsystem: "com.LloydME.SwiftBiomes",
    category: "StructureLoading"
)

enum StructureOverlayType: String, CaseIterable, Sendable {
    case village
    case desertPyramid
    case jungleTemple
    case swampHut
    case igloo
    case oceanRuin
    case shipwreck
    case monument
    case mansion
    case outpost
    case ruinedPortal
    case netherRuinedPortal
    case ancientCity
    case treasure
    case mineshaft
    case desertWell
    case geode
    case fortress
    case bastion
    case endCity
    case endGateway
    case endIsland
    case trailRuins
    case trialChambers
    case stronghold
    case slimeChunk

    static func available(in dimension: DimensionOption) -> [StructureOverlayType] {
        allCases.filter { $0.dimension == dimension }
    }

    var dimension: DimensionOption {
        switch self {
        case .netherRuinedPortal, .fortress, .bastion:
            return .nether
        case .endCity, .endGateway, .endIsland:
            return .end
        default:
            return .overworld
        }
    }

    var title: String {
        switch self {
        case .desertPyramid: return "Desert Pyramid"
        case .jungleTemple: return "Jungle Temple"
        case .swampHut: return "Swamp Hut"
        case .oceanRuin: return "Ocean Ruin"
        case .ruinedPortal: return "Ruined Portal"
        case .netherRuinedPortal: return "Nether Ruined Portal"
        case .ancientCity: return "Ancient City"
        case .endCity: return "End City"
        case .endGateway: return "End Gateway"
        case .endIsland: return "End Island"
        case .trailRuins: return "Trail Ruins"
        case .trialChambers: return "Trial Chambers"
        case .slimeChunk: return "Slime Chunk"
        default:
            return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var coreType: StructureType {
        switch self {
        case .village: return .village
        case .desertPyramid: return .desertPyramid
        case .jungleTemple: return .jungleTemple
        case .swampHut: return .swampHut
        case .igloo: return .igloo
        case .oceanRuin: return .oceanRuin
        case .shipwreck: return .shipwreck
        case .monument: return .monument
        case .mansion: return .mansion
        case .outpost: return .outpost
        case .ruinedPortal: return .ruinedPortal
        case .netherRuinedPortal: return .netherRuinedPortal
        case .ancientCity: return .ancientCity
        case .treasure: return .treasure
        case .mineshaft: return .mineshaft
        case .desertWell: return .desertWell
        case .geode: return .geode
        case .fortress: return .fortress
        case .bastion: return .bastion
        case .endCity: return .endCity
        case .endGateway: return .endGateway
        case .endIsland: return .endIsland
        case .trailRuins: return .trailRuins
        case .trialChambers: return .trialChambers
        case .stronghold: return .stronghold
        case .slimeChunk: return .slimeChunk
        }
    }

    var iconResourceName: String {
        switch self {
        case .village: return "village"
        case .desertPyramid: return "desert"
        case .jungleTemple: return "jungle"
        case .swampHut: return "hut"
        case .igloo: return "igloo"
        case .oceanRuin: return "ruins"
        case .shipwreck: return "shipwreck"
        case .monument: return "monument"
        case .mansion: return "mansion"
        case .outpost: return "outpost"
        case .ruinedPortal: return "portal"
        case .netherRuinedPortal: return "nether"
        case .ancientCity: return "ancient_city"
        case .treasure: return "treasure"
        case .mineshaft: return "mineshaft"
        case .desertWell: return "well"
        case .geode: return "geode"
        case .fortress: return "fortress"
        case .bastion: return "bastion"
        case .endCity: return "endcity"
        case .endGateway: return "gateway"
        case .endIsland: return "the_end"
        case .trailRuins: return "trails"
        case .trialChambers: return "chambers"
        case .stronghold: return "stronghold"
        case .slimeChunk: return "slime"
        }
    }

    init?(coreType: StructureType) {
        switch coreType {
        case .feature: return nil
        case .village: self = .village
        case .desertPyramid: self = .desertPyramid
        case .jungleTemple: self = .jungleTemple
        case .swampHut: self = .swampHut
        case .igloo: self = .igloo
        case .oceanRuin: self = .oceanRuin
        case .shipwreck: self = .shipwreck
        case .monument: self = .monument
        case .mansion: self = .mansion
        case .outpost: self = .outpost
        case .ruinedPortal: self = .ruinedPortal
        case .netherRuinedPortal: self = .netherRuinedPortal
        case .ancientCity: self = .ancientCity
        case .treasure: self = .treasure
        case .mineshaft: self = .mineshaft
        case .desertWell: self = .desertWell
        case .geode: self = .geode
        case .fortress: self = .fortress
        case .bastion: self = .bastion
        case .endCity: self = .endCity
        case .endGateway: self = .endGateway
        case .endIsland: self = .endIsland
        case .trailRuins: self = .trailRuins
        case .trialChambers: self = .trialChambers
        case .stronghold: self = .stronghold
        case .slimeChunk: self = .slimeChunk
        }
    }
}

struct StructureOverlayPoint: Equatable, Sendable {
    let type: StructureOverlayType
    let x: Int32
    let z: Int32
    let label: String
    let isViable: Bool

    var inspectorText: String {
        let viability = isViable ? "viable" : "candidate"
        if type == .slimeChunk {
            return "\(label), \(viability), Chunk \(floorDiv(x, 16)), \(floorDiv(z, 16)), origin X \(x), Z \(z)"
        }
        return "\(label), \(viability), X \(x), Z \(z)"
    }

    private func floorDiv(_ value: Int32, _ divisor: Int32) -> Int32 {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }
}

enum StructureOverlayStatus: Equatable, Sendable {
    case disabled
    case noneSelected
    case loading
    case loaded(Int)
    case empty
    case selected(StructureOverlayPoint)
    case failed(String)
}

struct StructureOverlayResult: Equatable, Sendable {
    let points: [StructureOverlayPoint]
    let status: StructureOverlayStatus
}

struct StructureOverlayCacheKey: Equatable, Sendable {
    let settings: WorldSettings
    let rect: BiomeMapVisibleRect
    let types: Set<StructureOverlayType>

    var cacheKey: String {
        let typeKey = types.map(\.rawValue).sorted().joined(separator: ",")
        return "\(settings.seed)-\(settings.version.label)-\(settings.dimension.rawValue)-\(rect.minX)-\(rect.minZ)-\(rect.maxX)-\(rect.maxZ)-\(typeKey)"
    }
}

struct StructureOverlayCacheIdentity: Equatable, Sendable {
    let settings: WorldSettings
    let types: Set<StructureOverlayType>
}

struct StructureOverlayCacheEntry: Equatable, Sendable {
    let identity: StructureOverlayCacheIdentity
    let coverage: BiomeMapVisibleRect
    let result: StructureOverlayResult

    func contains(
        settings: WorldSettings,
        types: Set<StructureOverlayType>,
        visibleRect: BiomeMapVisibleRect
    ) -> Bool {
        identity == StructureOverlayCacheIdentity(settings: settings, types: types) &&
            coverage.contains(visibleRect)
    }
}

private final class StrongholdLocationsCache: @unchecked Sendable {
    private struct Entry {
        let settings: WorldSettings
        let locations: [StructureLocation]
    }

    private let lock = NSLock()
    private var entry: Entry?

    func locations(for settings: WorldSettings) -> [StructureLocation] {
        lock.lock()
        defer { lock.unlock() }

        if let entry, entry.settings == settings {
            return entry.locations
        }

        let world = CubiomesWorld(
            version: settings.version.version,
            seed: settings.seed,
            dimension: settings.dimension.dimension
        )
        let locations = world.strongholds().sorted {
            ($0.blockZ, $0.blockX) < ($1.blockZ, $1.blockX)
        }
        entry = Entry(settings: settings, locations: locations)
        return locations
    }
}

protocol StructureOverlayProviding: Sendable {
    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect, types: Set<StructureOverlayType>) -> StructureOverlayResult
}

final class CubiomesStructureOverlayProvider: StructureOverlayProviding, @unchecked Sendable {
    private let strongholdCache = StrongholdLocationsCache()

    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect, types: Set<StructureOverlayType>) -> StructureOverlayResult {
        guard !types.isEmpty else {
            return StructureOverlayResult(points: [], status: .noneSelected)
        }

        let signpostState = structureLoadingSignposter.beginInterval("Load Structures")
        defer {
            structureLoadingSignposter.endInterval("Load Structures", signpostState)
        }

        do {
            let rect = StructureRect(
                minX: visibleRect.minX,
                minZ: visibleRect.minZ,
                maxX: visibleRect.maxX,
                maxZ: visibleRect.maxZ
            )
            var locations: [StructureLocation] = []
            var unsupported: [StructureOverlayType] = []
            for type in types.sorted(by: { $0.title < $1.title }) {
                do {
                    let matches: [StructureLocation]
                    if type == .stronghold {
                        matches = strongholdCache.locations(for: settings).filter {
                            rect.contains(blockX: $0.blockX, blockZ: $0.blockZ)
                        }
                    } else {
                        matches = try CubiomesCore.structures(
                            version: settings.version.version,
                            seed: settings.seed,
                            dimension: settings.dimension.dimension,
                            types: [type.coreType],
                            rect: rect
                        )
                    }
                    locations.append(contentsOf: matches)
                } catch CubiomesError.unsupportedStructure(let unsupportedType, _, _) {
                    unsupported.append(StructureOverlayType(coreType: unsupportedType) ?? type)
                } catch CubiomesError.unsupportedStructureConfig(let unsupportedType, _) {
                    unsupported.append(StructureOverlayType(coreType: unsupportedType) ?? type)
                }
            }

            let viableLocations = locations.filter(\.isViable)
            let points = viableLocations.compactMap { location -> StructureOverlayPoint? in
                guard let type = StructureOverlayType(coreType: location.type) else {
                    return nil
                }
                return StructureOverlayPoint(
                    type: type,
                    x: location.blockX,
                    z: location.blockZ,
                    label: type.title,
                    isViable: location.isViable
                )
            }
            if points.isEmpty, unsupported.count == types.count, let firstUnsupported = unsupported.first {
                return StructureOverlayResult(
                    points: [],
                    status: .failed("\(firstUnsupported.title) is unsupported for this world.")
                )
            }
            return StructureOverlayResult(
                points: points,
                status: points.isEmpty ? .empty : .loaded(points.count)
            )
        } catch CubiomesError.invalidStructureRect {
            return StructureOverlayResult(points: [], status: .failed("Visible structure area is invalid."))
        } catch {
            return StructureOverlayResult(points: [], status: .failed("Unable to load structures."))
        }
    }
}
