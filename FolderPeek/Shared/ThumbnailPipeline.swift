import AppKit
import Foundation
import QuickLookThumbnailing

public protocol CancellableThumbnailRequest: AnyObject {
    func cancel()
}

public protocol ThumbnailImageProvider: AnyObject {
    @discardableResult
    func generateThumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat,
        completion: @escaping @Sendable (Result<NSImage, Error>) -> Void
    ) -> CancellableThumbnailRequest?
}

public enum FolderPeekThumbnailRenderState: String, Equatable {
    case rendered
    case placeholder
    case cancelled
}

public struct FolderPeekRenderedThumbnail: Identifiable, Equatable {
    public let id: String
    public let candidate: FolderPeekThumbnailCandidate
    public let image: NSImage?
    public let state: FolderPeekThumbnailRenderState
    public let errorDescription: String?

    public init(
        candidate: FolderPeekThumbnailCandidate,
        image: NSImage?,
        state: FolderPeekThumbnailRenderState,
        errorDescription: String?
    ) {
        self.id = candidate.id
        self.candidate = candidate
        self.image = image
        self.state = state
        self.errorDescription = errorDescription
    }
}

public final class QuickLookThumbnailProvider: ThumbnailImageProvider {
    public init() {}

    @discardableResult
    public func generateThumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat,
        completion: @escaping @Sendable (Result<NSImage, Error>) -> Void
    ) -> CancellableThumbnailRequest? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: [.thumbnail, .icon]
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            if let image = representation?.nsImage {
                completion(.success(image))
            } else {
                completion(.failure(error ?? CocoaError(.fileNoSuchFile)))
            }
        }
        return QuickLookThumbnailCancellation(request: request)
    }
}

private final class QuickLookThumbnailCancellation: CancellableThumbnailRequest {
    private let request: QLThumbnailGenerator.Request

    init(request: QLThumbnailGenerator.Request) {
        self.request = request
    }

    func cancel() {
        QLThumbnailGenerator.shared.cancel(request)
    }
}

public final class ThumbnailPipeline {
    private let provider: ThumbnailImageProvider
    private let queue: DispatchQueue

    public init(provider: ThumbnailImageProvider = QuickLookThumbnailProvider(), queue: DispatchQueue = .global(qos: .userInitiated)) {
        self.provider = provider
        self.queue = queue
    }

    public func render(
        candidates: [FolderPeekThumbnailCandidate],
        maxCount: Int,
        size: CGSize = CGSize(width: 160, height: 160),
        scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0,
        timeout: TimeInterval = 1.0,
        completion: @escaping @Sendable ([FolderPeekRenderedThumbnail]) -> Void
    ) {
        let boundedCandidates = Array(candidates.prefix(max(0, maxCount)))
        guard !boundedCandidates.isEmpty else {
            completion([])
            return
        }

        let accumulator = ThumbnailPipelineAccumulator(candidates: boundedCandidates, completion: completion)

        for candidate in boundedCandidates {
            let slot = ThumbnailPipelineSlot()
            let timeoutWork = DispatchWorkItem {
                let request = slot.markTimedOut()
                request?.cancel()
                accumulator.finish(FolderPeekRenderedThumbnail(
                    candidate: candidate,
                    image: nil,
                    state: .cancelled,
                    errorDescription: "Thumbnail generation timed out."
                ))
            }

            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
            let request = provider.generateThumbnail(for: candidate.url, size: size, scale: scale) { result in
                guard slot.markCompleted() else { return }

                switch result {
                case .success(let image):
                    accumulator.finish(FolderPeekRenderedThumbnail(candidate: candidate, image: image, state: .rendered, errorDescription: nil))
                case .failure(let error):
                    accumulator.finish(FolderPeekRenderedThumbnail(candidate: candidate, image: nil, state: .placeholder, errorDescription: error.localizedDescription))
                }
            }
            slot.setCancellation(request)
        }
    }
}

private final class ThumbnailPipelineAccumulator: @unchecked Sendable {
    private let candidates: [FolderPeekThumbnailCandidate]
    private let completion: @Sendable ([FolderPeekRenderedThumbnail]) -> Void
    private let lock = NSLock()
    private var remaining: Int
    private var resultsByID: [String: FolderPeekRenderedThumbnail] = [:]

    init(candidates: [FolderPeekThumbnailCandidate], completion: @escaping @Sendable ([FolderPeekRenderedThumbnail]) -> Void) {
        self.candidates = candidates
        self.completion = completion
        self.remaining = candidates.count
    }

    func finish(_ result: FolderPeekRenderedThumbnail) {
        lock.lock()
        resultsByID[result.id] = result
        remaining -= 1
        let isComplete = remaining == 0
        let ordered = candidates.compactMap { resultsByID[$0.id] }
        lock.unlock()

        if isComplete {
            completion(ordered)
        }
    }
}

private final class ThumbnailPipelineSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    private var cancellation: CancellableThumbnailRequest?

    func setCancellation(_ request: CancellableThumbnailRequest?) {
        var requestToCancel: CancellableThumbnailRequest?
        lock.lock()
        if didFinish {
            requestToCancel = request
        } else {
            cancellation = request
        }
        lock.unlock()
        requestToCancel?.cancel()
    }

    func markTimedOut() -> CancellableThumbnailRequest? {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return nil }
        didFinish = true
        return cancellation
    }

    func markCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return false }
        didFinish = true
        return true
    }
}
