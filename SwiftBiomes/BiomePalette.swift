import AppKit

enum BiomePalette {
    static func color(for biomeName: String) -> NSColor {
        let rgba = rgba(for: biomeName)
        return NSColor(
            calibratedRed: CGFloat(rgba.red) / 255.0,
            green: CGFloat(rgba.green) / 255.0,
            blue: CGFloat(rgba.blue) / 255.0,
            alpha: CGFloat(rgba.alpha) / 255.0
        )
    }

    static func rgba(for biomeName: String) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let name = biomeName.lowercased()

        if name.contains("mushroom") {
            return (179, 117, 184, 255)
        }

        if name.contains("ocean") || name.contains("river") {
            return (36, 87, 171, 255)
        }

        if name.contains("desert") || name.contains("badlands") || name.contains("savanna") {
            return (199, 163, 87, 255)
        }

        if name.contains("snow") || name.contains("ice") || name.contains("frozen") {
            return (194, 219, 230, 255)
        }

        if name.contains("jungle") {
            return (51, 122, 56, 255)
        }

        if name.contains("taiga") || name.contains("grove") {
            return (61, 107, 87, 255)
        }

        if name.contains("forest") {
            return (66, 128, 69, 255)
        }

        if name.contains("swamp") || name.contains("mangrove") {
            return (79, 99, 56, 255)
        }

        if name.contains("plains") || name.contains("meadow") {
            return (120, 166, 92, 255)
        }

        if name.contains("nether") || name.contains("crimson") {
            return (122, 41, 33, 255)
        }

        if name.contains("warped") {
            return (31, 112, 110, 255)
        }

        if name.contains("end") {
            return (140, 133, 87, 255)
        }

        return (107, 140, 97, 255)
    }

    static func rgba(forBiomeID biomeID: Int32) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        switch biomeID {
        case 0, 7, 10, 11, 24, 44...50:
            return (36, 87, 171, 255)
        case 2, 17, 37...39, 130, 165...167:
            return (199, 163, 87, 255)
        case 12, 13, 26, 30, 31, 140, 158, 179...181:
            return (194, 219, 230, 255)
        case 14, 15:
            return (179, 117, 184, 255)
        case 21...23, 149...151, 168, 169:
            return (51, 122, 56, 255)
        case 5, 19, 32, 33, 133, 160, 161, 178:
            return (61, 107, 87, 255)
        case 4, 18, 27...29, 34, 132, 155...157, 185, 186:
            return (66, 128, 69, 255)
        case 6, 134, 184:
            return (79, 99, 56, 255)
        case 1, 129, 177:
            return (120, 166, 92, 255)
        case 8, 170, 171, 173:
            return (122, 41, 33, 255)
        case 172:
            return (31, 112, 110, 255)
        case 9, 40...43:
            return (140, 133, 87, 255)
        case 3, 20, 25, 131, 162, 182:
            return (128, 132, 104, 255)
        default:
            return (107, 140, 97, 255)
        }
    }
}
