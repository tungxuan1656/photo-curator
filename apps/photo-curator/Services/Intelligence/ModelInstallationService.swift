import Foundation

enum ModelInstallationFailure: Error, Equatable, Sendable {
    case cancelled
    case diskSpace
    case invalidResponse
    case invalidArtifact(String)
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
    let bytes: AsyncThrowingStream<UInt8, Error>
}

typealias ModelDownloader = @Sendable (URLRequest) async throws -> ModelDownloadResponse

/// Downloads one frozen model revision without exposing network access to inference.
actor ModelInstallationService {
    private let manifest: ModelManifest
    private let rootDirectory: URL
    private let downloader: ModelDownloader
    private var state: ModelInstallationState = .notInstalled
    private var verifiedInstallation: ModelInstallation?
    private var installationTask: Task<ModelInstallation, Error>?
    private var observers: [UUID: AsyncStream<ModelInstallationState>.Continuation] = [:]

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

    func remove() throws {
        guard installationTask == nil else {
            throw ModelInstallationFailure.io
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
        let requestURL = try sourceURL(for: file)
        var request = URLRequest(url: requestURL)
        if partialBytes > 0 {
            request.setValue("bytes=\(partialBytes)-", forHTTPHeaderField: "Range")
        }

        let response = try await downloader(request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw ModelInstallationFailure.network
        }
        if partialBytes > 0, response.statusCode != 206 {
            try? FileManager.default.removeItem(at: partial)
            return try await download(file, into: directory)
        }

        let handle = try openPartialFile(at: partial, append: partialBytes > 0)
        let written = try await append(
            response.bytes,
            to: handle,
            initialByteCount: partialBytes,
            completedBeforeFile: completedBeforeFile
        )
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

    private func openPartialFile(at url: URL, append: Bool) throws -> FileHandle {
        if append {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            return handle
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try FileHandle(forWritingTo: url)
    }

    private func append(
        _ bytes: AsyncThrowingStream<UInt8, Error>,
        to handle: FileHandle,
        initialByteCount: Int64,
        completedBeforeFile: Int64
    ) async throws -> Int64 {
        defer { try? handle.close() }
        var written = initialByteCount
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                publish(
                    .downloading(
                        completedBytes: completedBeforeFile + written,
                        totalBytes: manifest.totalByteCount
                    )
                )
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
        }
        return written
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

    private static let liveDownloader: ModelDownloader = { request in
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ModelInstallationFailure.invalidResponse
        }
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                do {
                    for try await byte in bytes {
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        return ModelDownloadResponse(statusCode: response.statusCode, bytes: stream)
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
