import Foundation

/// Errors thrown by FileStore.
enum FileStoreError: Error, Sendable {
    case pathEscapesRoot(String)
}

/// Serialized file access for small Codable values only.
/// Holds derived data and manifests, never image pixels or face data.
/// All callers cross actor isolation with await.
actor FileStore {
    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    private func url(for relativePath: String) throws -> URL {
        let base = rootDirectory.standardizedFileURL
        let target = base.appendingPathComponent(relativePath).standardizedFileURL
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard target.path == base.path || target.path.hasPrefix(prefix) else {
            throw FileStoreError.pathEscapesRoot(relativePath)
        }
        return target
    }

    /// Note: constrained to Codable only (not Sendable) because the app target defaults to
    /// MainActor isolation, so G0 model conformances cannot satisfy a Sendable type parameter.
    func save<T: Codable>(_ value: T, to relativePath: String) throws {
        let target = try url(for: relativePath)
        let folder = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: target, options: .atomic)
    }

    func load<T: Codable>(_ type: T.Type, from relativePath: String) throws -> T {
        let target = try url(for: relativePath)
        let data = try Data(contentsOf: target)
        return try JSONDecoder().decode(type, from: data)
    }

    func remove(relativePath: String) throws {
        let target = try url(for: relativePath)
        try FileManager.default.removeItem(at: target)
    }

    func exists(relativePath: String) -> Bool {
        guard let target = try? url(for: relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: target.path)
    }
}
