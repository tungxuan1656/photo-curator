import CryptoKit
import Foundation

private final class FailureSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var shouldFail = true

    func consumeFailure() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard shouldFail else { return false }
        shouldFail = false
        return true
    }
}

@main
struct Feat031InstallationProof {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("feat-031-installation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let weights = Data(repeating: 7, count: 128 * 1024)
        let files = [ModelArtifactFile(
            path: "weights.bin", byteCount: Int64(weights.count), sha256: digest(weights)
        )]
        let manifest = ModelManifest(
            schemaVersion: 1,
            modelID: "local/test-model",
            revision: "proof-revision",
            runtimeRevision: "proof-runtime",
            license: "Apache-2.0",
            files: files
        )
        let failureSwitch = FailureSwitch()
        let downloader: ModelDownloader = { request in
            let offset = request.value(forHTTPHeaderField: "Range")
                .flatMap { $0.split(separator: "=").last?.split(separator: "-").first }
                .flatMap { Int($0) } ?? 0
            let shouldFail = offset == 0 && failureSwitch.consumeFailure()
            let end = shouldFail ? 70 * 1024 : weights.count
            let payload = Data(weights[offset ..< end])
            let stream = AsyncThrowingStream<UInt8, Error> { continuation in
                for byte in payload {
                    continuation.yield(byte)
                }
                if shouldFail {
                    continuation.finish(throwing: ModelInstallationFailure.network)
                } else {
                    continuation.finish()
                }
            }
            return ModelDownloadResponse(statusCode: offset == 0 ? 200 : 206, bytes: stream)
        }

        let service = ModelInstallationService(
            manifest: manifest, rootDirectory: root, downloader: downloader
        )
        let states = await service.stateStream()
        let observed = Task { () -> [ModelInstallationState] in
            var values: [ModelInstallationState] = []
            for await state in states {
                values.append(state)
                if state == .installed {
                    break
                }
            }
            return values
        }

        do {
            _ = try await service.install()
            fatalError("interrupted install unexpectedly succeeded")
        } catch {
            guard case .failed = await service.currentState() else {
                fatalError("interrupted install did not publish failed state")
            }
        }
        print("INTERRUPT-FAILURE PASS")

        let installation = try await service.install()
        try manifest.validate(at: installation.directory)
        guard await service.currentState() == .installed else {
            fatalError("completed install did not publish installed state")
        }
        let values = await observed.value
        guard values.contains(where: {
            if case .downloading = $0 {
                return true
            }; return false
        }),
            values.contains(.verifying("weights.bin"))
        else {
            fatalError("installation state stream missed download or verification")
        }
        print("RESUME-AND-HASH PASS")
        print("ATOMIC-ACTIVATION PASS")

        try await service.remove()
        guard await service.currentState() == .notInstalled,
              !FileManager.default.fileExists(atPath: installation.directory.path)
        else {
            fatalError("remove did not clear the installed revision")
        }
        print("REMOVE PASS")
        print("RESULT PASS")
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
