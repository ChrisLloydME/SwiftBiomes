import Foundation

@MainActor
final class BiomeQueryViewModel {
    enum State: Equatable {
        case empty
        case loading(BiomeQueryRequest)
        case result(BiomeDisplayResult)
        case failed(String)
    }

    enum QueryError: Error, Equatable {
        case invalidSeed
        case invalidCoordinate

        var message: String {
            switch self {
            case .invalidSeed:
                return "Enter a whole-number seed."
            case .invalidCoordinate:
                return "Enter whole-number X and Z coordinates."
            }
        }
    }

    private let service: any BiomeProviding
    private var currentTask: Task<Void, Never>?

    var settings: WorldSettings
    var x: Int32
    var z: Int32
    private(set) var state: State = .empty

    var onChange: ((BiomeQueryViewModel) -> Void)?

    init(
        settings: WorldSettings = .sample,
        x: Int32 = 0,
        z: Int32 = 0,
        service: any BiomeProviding = CubiomesBiomeService()
    ) {
        self.settings = settings
        self.x = x
        self.z = z
        self.service = service
    }

    deinit {
        currentTask?.cancel()
    }

    var currentRequest: BiomeQueryRequest {
        BiomeQueryRequest(settings: settings, x: x, z: z)
    }

    func apply(seedText: String, xText: String, zText: String, versionIndex: Int, dimensionIndex: Int) throws {
        settings.seed = try BiomeQueryValidation.parseSeed(seedText)
        x = try BiomeQueryValidation.parseCoordinate(xText)
        z = try BiomeQueryValidation.parseCoordinate(zText)

        if MinecraftVersionOption.supported.indices.contains(versionIndex) {
            settings.version = MinecraftVersionOption.supported[versionIndex]
        }

        if DimensionOption.allCases.indices.contains(dimensionIndex) {
            settings.dimension = DimensionOption.allCases[dimensionIndex]
        }
    }

    func submitQuery() {
        let request = currentRequest
        currentTask?.cancel()
        state = .loading(request)
        notify()

        currentTask = Task { [service] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try service.biome(for: request)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                state = .result(result)
            } catch let error as QueryError {
                state = .failed(error.message)
            } catch {
                state = .failed("Biome lookup failed. Check the selected version, dimension, seed, and coordinate.")
            }

            notify()
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func notify() {
        onChange?(self)
    }
}
