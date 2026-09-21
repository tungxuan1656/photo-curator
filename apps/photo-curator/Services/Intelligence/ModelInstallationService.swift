import Foundation

enum ModelInstallationFailure: Error, Equatable, Sendable {
    case cancelled
    case diskSpace
    case invalidResponse
    case invalidArtifact(String)
    case inferenceLeaseActive
    case io
    case network
}

enum ModelInstallationState: Equatable, Sendable {
    case notInstalled
    case downloading(completedBytes: Int64, totalBytes: Int64)
    case verifying(String)
    case paused(completedBytes: Int64, totalBytes: Int64)
    case installed
    case failed(ModelInstallationFailure)
}

struct ModelInstallation: Sendable {
    let directory: URL
    let modelID: String
    let revision: String
    let manifestDigest: String
}

struct ModelDownloadResponse: Sendable {
    let statusCode: Int
}

struct ModelDownloadRequest: Sendable {
    let request: URLRequest
    let destinationURL: URL
    let append: Bool
    let progress: @Sendable (Int64) -> Void
}

typealias ModelDownloader = @Sendable (ModelDownloadRequest) async throws -> ModelDownloadResponse

/// Downloads one frozen model revision without exposing network access to inference.
actor ModelInstallationService {
    private let manifest: ModelManifest
    private let rootDirectory: URL
    private let downloader: ModelDownloader
    private var state: ModelInstallationState = .notInstalled
    private var verifiedInstallation: ModelInstallation?
    private var installationTask: Task<ModelInstallation, Error>?
    private var inferenceLeaseCount = 0
    private var removalInProgress = false
    private var inferenceLeaseWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var observers: [UUID: AsyncStream<ModelInstallationState>.Continuation] = [:]
    private var activeDownloadProgressID: UUID?

    init(
        manifest: ModelManifest = .qwen35TwoBFourBit,
        rootDirectory: URL,
        downloader: @escaping ModelDownloader = ModelInstallationService.liveDownloader
    ) {
        self.manifest = manifest
        self.rootDirectory = rootDirectory
        self.downloader = downloader
    }

    func currentState() -> ModelInstallationState {
        state
    }

    /// Revalidates the active revision without network access. Callers use this
    /// after launch before offering a model-backed run.
    func installedModel() -> ModelInstallation? {
        if let verifiedInstallation {
            return verifiedInstallation
        }
        guard installationTask == nil, FileManager.default.fileExists(atPath: revisionDirectory.path) else {
            return nil
        }
        do {
            try manifest.validate(at: revisionDirectory)
            let installation = installation(at: revisionDirectory)
            verifiedInstallation = installation
            publish(.installed)
            return installation
        } catch {
            publish(.notInstalled)
            return nil
        }
    }

    func stateStream() -> AsyncStream<ModelInstallationState> {
        let (stream, continuation) = AsyncStream<ModelInstallationState>.makeStream()
        let id = UUID()
        observers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    func install() async throws -> ModelInstallation {
        if let installationTask {
            return try await installationTask.value
        }
        guard !removalInProgress else {
            throw ModelInstallationFailure.io
        }

        let task = Task { [self] in
            do {
                let installation = try await performInstall()
                verifiedInstallation = installation
                publish(.installed)
                return installation
            } catch is CancellationError {
                publish(.paused(completedBytes: stagedByteCount(), totalBytes: manifest.totalByteCount))
                throw CancellationError()
            } catch let failure as ModelInstallationFailure {
                publish(.failed(failure))
                throw failure
            } catch {
                publish(.failed(.io))
                throw ModelInstallationFailure.io
            }
        }
        installationTask = task
        defer { installationTask = nil }
        return try await task.value
    }

    func cancel() {
        installationTask?.cancel()
    }

    func remove() async throws {
        guard installationTask == nil else {
            throw ModelInstallationFailure.io
        }
        guard !removalInProgress else {
            throw ModelInstallationFailure.inferenceLeaseActive
        }
        removalInProgress = true
        defer { removalInProgress = false }
        try await waitForInferenceLeases()
        try Task.checkCancellation()
        guard inferenceLeaseCount == 0 else {
            throw ModelInstallationFailure.inferenceLeaseActive
        }
        let directory = revisionDirectory
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        verifiedInstallation = nil
        state = .notInstalled
        publish(state)
    }

    private var revisionDirectory: URL {
        rootDirectory.appendingPathComponent(manifest.revision, isDirectory: true)
    }

    private var stagingDirectory: URL {
        rootDirectory
            .appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent(manifest.revision, isDirectory: true)
    }

    private func performInstall() async throws -> ModelInstallation {
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var excludedRoot = rootDirectory
        try? excludedRoot.setResourceValues(resourceValues)

        if FileManager.default.fileExists(atPath: revisionDirectory.path) {
            do {
                try manifest.validate(at: revisionDirectory)
                return installation(at: revisionDirectory)
            } catch {
                try? FileManager.default.removeItem(at: revisionDirectory)
            }
        }

        try checkDiskSpace()
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        for file in manifest.files {
            try Task.checkCancellation()
            try await download(file, into: stagingDirectory)
        }

        publish(.verifying("manifest"))
        do {
            try manifest.validate(at: stagingDirectory)
        } catch let error as ModelManifestError {
            throw ModelInstallationFailure.invalidArtifact(String(describing: error))
        }
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: revisionDirectory.path) {
            try FileManager.default.removeItem(at: revisionDirectory)
        }
        try FileManager.default.moveItem(at: stagingDirectory, to: revisionDirectory)
        return installation(at: revisionDirectory)
    }

    private func installation(at directory: URL) -> ModelInstallation {
        ModelInstallation(
            directory: directory,
            modelID: manifest.modelID,
            revision: manifest.revision,
            manifestDigest: manifest.manifestDigest
        )
    }

    private func download(_ file: ModelArtifactFile, into directory: URL) async throws {
        let destination = directory.appending(path: file.path)
        let partial = directory.appending(path: "\(file.path).partial")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: destination.path) {
            if (try? manifest.validate(file: file, at: directory)) != nil {
                return
            }
            try? FileManager.default.removeItem(at: destination)
        }

        let partialBytes = (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let completedBeforeFile = stagedByteCount(in: directory) - partialBytes
        let request = try downloadRequest(for: file, partialBytes: partialBytes)

        let progressID = UUID()
        activeDownloadProgressID = progressID
        defer {
            if activeDownloadProgressID == progressID {
                activeDownloadProgressID = nil
            }
        }
        publish(
            .downloading(
                completedBytes: completedBeforeFile + partialBytes,
                totalBytes: manifest.totalByteCount
            )
        )
        let progress = downloadProgressHandler(
            id: progressID,
            completedBeforeFile: completedBeforeFile
        )

        let response = try await downloader(
            ModelDownloadRequest(
                request: request,
                destinationURL: partial,
                append: partialBytes > 0,
                progress: progress
            )
        )
        guard (200 ... 299).contains(response.statusCode) else {
            throw ModelInstallationFailure.network
        }
        let written = (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        publish(
            .downloading(
                completedBytes: completedBeforeFile + written,
                totalBytes: manifest.totalByteCount
            )
        )
        try finalizeDownload(
            file,
            partial: partial,
            destination: destination,
            written: written,
            in: directory
        )
    }

    private static let liveDownloader: ModelDownloader = { downloadRequest in
        let delegate = ModelDownloadDelegate(
            destinationURL: downloadRequest.destinationURL,
            append: downloadRequest.append,
            progress: downloadRequest.progress
        )
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        let task = session.dataTask(with: downloadRequest.request)

        do {
            let response = try await delegate.awaitCompletion(for: task)
            session.finishTasksAndInvalidate()
            return response
        } catch {
            session.invalidateAndCancel()
            throw error
        }
    }

    private func publishDownloadProgress(
        id: UUID,
        fileBytes: Int64,
        completedBeforeFile: Int64
    ) {
        guard activeDownloadProgressID == id,
              case let .downloading(currentBytes, totalBytes) = state,
              fileBytes >= 0
        else { return }
        let completedBytes = min(completedBeforeFile + fileBytes, totalBytes)
        guard completedBytes >= currentBytes else { return }
        publish(.downloading(completedBytes: completedBytes, totalBytes: totalBytes))
    }

    private func checkDiskSpace() throws {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]
        guard let available = try rootDirectory.resourceValues(forKeys: keys).volumeAvailableCapacityForImportantUsage,
              available >= manifest.totalByteCount * 2
        else {
            throw ModelInstallationFailure.diskSpace
        }
    }

    private func stagedByteCount() -> Int64 {
        stagedByteCount(in: stagingDirectory)
    }

    private func stagedByteCount(in directory: URL) -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        return files.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func publish(_ newState: ModelInstallationState) {
        state = newState
        observers.values.forEach { _ = $0.yield(newState) }
    }

    private func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }
}

extension ModelInstallationService {
    private func downloadRequest(for file: ModelArtifactFile, partialBytes: Int64) throws -> URLRequest {
        var request = try URLRequest(url: sourceURL(for: file))
        if partialBytes > 0 {
            request.setValue("bytes=\(partialBytes)-", forHTTPHeaderField: "Range")
        }
        return request
    }

    private func downloadProgressHandler(
        id: UUID,
        completedBeforeFile: Int64
    ) -> @Sendable (Int64) -> Void {
        { [weak self] fileBytes in
            Task { [weak self] in
                await self?.publishDownloadProgress(
                    id: id,
                    fileBytes: fileBytes,
                    completedBeforeFile: completedBeforeFile
                )
            }
        }
    }

    private func sourceURL(for file: ModelArtifactFile) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/\(manifest.modelID)/resolve/\(manifest.revision)/\(file.path)"
        components.queryItems = [URLQueryItem(name: "download", value: "true")]
        guard let url = components.url else {
            throw ModelInstallationFailure.invalidArtifact(file.path)
        }
        return url
    }

    private func finalizeDownload(
        _ file: ModelArtifactFile,
        partial: URL,
        destination: URL,
        written: Int64,
        in directory: URL
    ) throws {
        guard written == file.byteCount else {
            try? FileManager.default.removeItem(at: partial)
            throw ModelInstallationFailure.invalidResponse
        }

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: partial, to: destination)
        publish(.verifying(file.path))
        do {
            try manifest.validate(file: file, at: directory)
        } catch let error as ModelManifestError {
            try? FileManager.default.removeItem(at: destination)
            throw ModelInstallationFailure.invalidArtifact(String(describing: error))
        }
    }

    func acquireInferenceLease(for installation: ModelInstallation) -> Bool {
        guard !removalInProgress,
              let verifiedInstallation,
              verifiedInstallation.directory == installation.directory,
              verifiedInstallation.revision == installation.revision,
              verifiedInstallation.manifestDigest == installation.manifestDigest
        else { return false }
        inferenceLeaseCount += 1
        return true
    }

    func releaseInferenceLease() {
        inferenceLeaseCount = max(0, inferenceLeaseCount - 1)
        guard inferenceLeaseCount == 0 else { return }
        let waiters = inferenceLeaseWaiters.values
        inferenceLeaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: ())
        }
    }

    private func waitForInferenceLeases() async throws {
        guard inferenceLeaseCount > 0 else { return }
        let waiterID = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if inferenceLeaseCount == 0 || Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    inferenceLeaseWaiters[waiterID] = continuation
                }
            }
        }, onCancel: { [weak self] in
            Task { await self?.cancelInferenceLeaseWaiter(waiterID) }
        })
    }

    private func cancelInferenceLeaseWaiter(_ waiterID: UUID) {
        guard let waiter = inferenceLeaseWaiters.removeValue(forKey: waiterID) else { return }
        waiter.resume(throwing: CancellationError())
    }
}
