import Foundation

enum StructureOverlayKind: String, CaseIterable, Sendable {
    case villages = "Villages"
    case strongholds = "Strongholds"
    case monuments = "Monuments"
}

struct StructureOverlayPoint: Equatable, Sendable {
    let kind: StructureOverlayKind
    let x: Int32
    let z: Int32
    let label: String
}

protocol StructureOverlayProviding: Sendable {
    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect) -> [StructureOverlayPoint]
    var limitation: String? { get }
}

struct CubiomesStructureOverlayProvider: StructureOverlayProviding {
    var limitation: String? {
        "Structure overlays are wired in the UI, but CubiomesCore currently exposes only biome lookup through its public Swift API."
    }

    func points(for settings: WorldSettings, visibleRect: BiomeMapVisibleRect) -> [StructureOverlayPoint] {
        []
    }
}
