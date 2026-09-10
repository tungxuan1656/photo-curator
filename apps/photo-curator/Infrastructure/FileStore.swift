import Foundation

/// Serialized file access for small Codable values only.
/// Holds derived data and manifests, never image pixels or face data.
/// All callers cross actor isolation with await.
actor FileStore {
    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    private func url(for relativePath: String) -> URL {
        rootDirectory.appendingPathComponent(relativePath)
    }

    /// Note: constrained to Codable only (not Sendable) because the app target defaults to
    /// MainActor isolation, so G0 model conformances cannot satisfy a Sendable type parameter.
    func save<T: Codable>(_ value: T, to relativePath: String) throws {
        let target = url(for: relativePath)
        let folder = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: target, options: .atomic)
    }

    func load<T: Codable>(_ type: T.Type, from relativePath: String) throws -> T {
        let target = url(for: relativePath)
        let data = try Data(contentsOf: target)
        return try JSONDecoder().decode(type, from: data)
    }

    func remove(relativePath: String) throws {
        let target = url(for: relativePath)
        try FileManager.default.removeItem(at: target)
    }

    func exists(relativePath: String) -> Bool {
        let target = url(for: relativePath)
        return FileManager.default.fileExists(atPath: target.path)
    }
}
