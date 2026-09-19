import Foundation

/// Writes URLSession data callbacks directly to the resumable model artifact.
final class ModelDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let writeChunkSize = 256 * 1024
    private static let progressInterval: TimeInterval = 0.25

    private let destinationURL: URL
    private let append: Bool
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var responseContinuation: CheckedContinuation<ModelDownloadResponse, Error>?
    private var response: HTTPURLResponse?
    private var fileHandle: FileHandle?
    private var writeBuffer = Data()
    private var bytesWritten: Int64 = 0
    private var lastProgressBytes: Int64 = 0
    private var lastProgressAt = Date(timeIntervalSince1970: 0)
    private var finished = false

    init(
        destinationURL: URL,
        append: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) {
        self.destinationURL = destinationURL
        self.append = append
        self.progress = progress
        writeBuffer.reserveCapacity(Self.writeChunkSize)
    }

    func awaitCompletion(for task: URLSessionDataTask) async throws -> ModelDownloadResponse {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
                ModelDownloadResponse,
                Error
            >) in
                lock.lock()
                responseContinuation = continuation
                lock.unlock()
                task.resume()
            }
        }, onCancel: {
            task.cancel()
        })
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse else {
            finish(throwing: ModelInstallationFailure.invalidResponse)
            completionHandler(.cancel)
            return
        }
        self.response = response

        guard (200 ... 299).contains(response.statusCode) else {
            completionHandler(.allow)
            return
        }

        do {
            let fileReady = FileManager.default.fileExists(atPath: destinationURL.path)
                || FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
            if !fileReady {
                throw ModelInstallationFailure.io
            }
            let handle = try FileHandle(forWritingTo: destinationURL)
            if append, response.statusCode == 206 {
                try handle.seekToEnd()
                bytesWritten = try Int64(
                    (destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                )
            } else {
                try handle.truncate(atOffset: 0)
                bytesWritten = 0
            }
            fileHandle = handle
            completionHandler(.allow)
        } catch {
            finish(throwing: error)
            completionHandler(.cancel)
        }
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard fileHandle != nil else { return }
        do {
            writeBuffer.append(data)
            if writeBuffer.count >= Self.writeChunkSize {
                try flushBuffer()
            }
        } catch {
            finish(throwing: error)
            dataTask.cancel()
        }
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            try? flushBuffer()
            finish(throwing: normalized(error))
            return
        }

        do {
            try flushBuffer()
            finish(returning: ModelDownloadResponse(statusCode: response?.statusCode ?? 0))
        } catch {
            finish(throwing: error)
        }
    }

    private func flushBuffer() throws {
        guard !writeBuffer.isEmpty, let fileHandle else { return }
        try fileHandle.write(contentsOf: writeBuffer)
        bytesWritten += Int64(writeBuffer.count)
        writeBuffer.removeAll(keepingCapacity: true)

        let now = Date()
        let hasEnoughBytes = bytesWritten - lastProgressBytes >= Self.writeChunkSize
        let intervalElapsed = now.timeIntervalSince(lastProgressAt) >= Self.progressInterval
        if hasEnoughBytes, intervalElapsed {
            progress(bytesWritten)
            lastProgressBytes = bytesWritten
            lastProgressAt = now
        }
    }

    private func finish(returning response: ModelDownloadResponse) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = responseContinuation
        responseContinuation = nil
        lock.unlock()
        try? fileHandle?.close()
        continuation?.resume(returning: response)
    }

    private func finish(throwing error: Error) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = responseContinuation
        responseContinuation = nil
        lock.unlock()
        try? fileHandle?.close()
        continuation?.resume(throwing: error)
    }

    private func normalized(_ error: Error) -> Error {
        if (error as? URLError)?.code == .cancelled {
            return CancellationError()
        }
        return error
    }
}
