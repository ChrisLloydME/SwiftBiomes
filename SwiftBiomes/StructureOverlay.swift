import Foundation
import CubiomesCore

enum StructureOverlayType: String, CaseIterable, Sendable {
    case village
    case desertPyramid
    case jungleTemple
    case swampHut
    case igloo
    case monument
    case mansion
    case outpost
    case ruinedPortal
    case ancientCity
    case treasure
    case mineshaft
    case fortress
    case bastion
    case endCity
    case stronghold
    case slimeChunk

    var title: String {
        switch self {
        case .desertPyramid: return "Desert Pyramid"
        case .jungleTemple: return "Jungle Temple"
        case .swampHut: return "Swamp Hut"
        case .ruinedPortal: return "Ruined Portal"
        case .ancientCity: return "Ancient City"
        case .endCity: return "End City"
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
        case .monument: return .monument
        case .mansion: return .mansion
        case .outpost: return .outpost
        case .ruinedPortal: return .ruinedPortal
        case .ancientCity: return .ancientCity
        case .treasure: return .treasure
        case .mineshaft: return .mineshaft
        case .fortress: return .fortress
        case .bastion: return .bastion
        case .endCity: return .endCity
        case .stronghold: return .stronghold
        case .slimeChunk: return .slimeChunk
        }
    }

    init(coreType: StructureType) {
        switch coreType {
        case .village: self = .village
        case .desertPyramid: self = .desertPyramid
        case .jungleTemple: self = .jungleTemple
        case .swampHut: self = .swampHut
        case .igloo: self = .igloo
        case .monument: self = .monument
        case .mansion: self = .mansion
        case .outpost: self = .outpost
        case .ruinedPortal: self = .ruinedPortal
        case .ancientCity: self = .ancientCity
        case .treasure: self = .treasure
        case .mineshaft: self = .mineshaft
        case .fortress: self = .fortress
        case .bastion: self = .bastion
        case .endCity: self = .endCity
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
}

enum StructureOverlayStatus: Equatable, Sendable {
    case disabled
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

protocol StructureOverlayProviding: Sendable {
    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect, types: Set<StructureOverlayType>) -> StructureOverlayResult
}

struct CubiomesStructureOverlayProvider: StructureOverlayProviding {
    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect, types: Set<StructureOverlayType>) -> StructureOverlayResult {
        guard !types.isEmpty else {
            return StructureOverlayResult(points: [], status: .empty)
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
                    locations.append(contentsOf: try CubiomesCore.structures(
                        version: settings.version.version,
                        seed: settings.seed,
                        dimension: settings.dimension.dimension,
                        types: [type.coreType],
                        rect: rect
                    ))
                } catch CubiomesError.unsupportedStructure {
                    unsupported.append(type)
                }
            }

            let viableLocations = locations.filter(\.isViable)
            let points = viableLocations.map { location in
                let type = StructureOverlayType(coreType: location.type)
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
