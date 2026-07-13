import Foundation
import CubiomesCore

@MainActor
final class SeedFinderViewModel {
    enum State: Equatable {
        case idle
        case searching(SeedFinderProgress)
        case finished([SeedFinderResult])
        case cancelled([SeedFinderResult])
        case failed(String)
    }

    private let finder: any SeedFinding
    private var task: Task<Void, Never>?
    private var cancellationToken: CubiomesSearchCancellationToken?

    private(set) var state: State = .idle
    var onChange: ((SeedFinderViewModel) -> Void)?

    init(finder: (any SeedFinding)? = nil) {
        self.finder = finder ?? CubiomesSeedFinder()
    }

    deinit {
        cancellationToken?.cancel()
        task?.cancel()
    }

    func start(_ request: SeedFinderRequest) {
        do {
            let totalSeeds = try request.validatedSeedCount()
            cancelCurrentSearch()

            let token = CubiomesSearchCancellationToken()
            cancellationToken = token
            state = .searching(SeedFinderProgress(
                checkedSeeds: 0,
                totalSeeds: totalSeeds,
                matchedResults: 0,
                currentSeed: request.startSeed
            ))
            notify()

            task = Task { [weak self, finder] in
                let outcome = await Task.detached(priority: .userInitiated) {
                    Result {
                        try finder.findSeeds(for: request, cancellationToken: token) { progress in
                            Task { @MainActor [weak self] in
                                guard self?.cancellationToken === token else {
                                    return
                                }
                                self?.state = .searching(progress)
                                self?.notify()
                            }
                        }
                    }
                }.value

                guard let self, cancellationToken === token else {
                    return
                }

                switch outcome {
                case .success(let results):
                    state = token.isCancelled ? .cancelled(results) : .finished(results)
                case .failure(let error as SeedFinderError):
                    state = .failed(error.message)
                case .failure:
                    state = .failed("Seed search failed. Check the selected world and search conditions.")
                }
                cancellationToken = nil
                task = nil
                notify()
            }
        } catch let error as SeedFinderError {
            state = .failed(error.message)
            notify()
        } catch {
            state = .failed("Unable to start seed search.")
            notify()
        }
    }

    func cancel() {
        cancellationToken?.cancel()
    }

    private func cancelCurrentSearch() {
        cancellationToken?.cancel()
        task?.cancel()
        task = nil
        cancellationToken = nil
    }

    private func notify() {
        onChange?(self)
    }
}
