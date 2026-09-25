import Foundation

/// Errors thrown by FileStore.
enum FileStoreError: Error, Sendable {
    case pathEscapesRoot(String)
}

/// Serialized file access for small Codable values only.
/// Holds derived data and manifests, never image pixels or face data.
/// All callers cross actor isolation with await.
actor FileStore {
    struct JSONFileListing: Sendable {
        let files: [String]
        let isAvailable: Bool
    }

    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    private func url(for relativePath: String) throws -> URL {
        let base = rootDirectory.standardizedFileURL
        let target = base.appendingPathComponent(relativePath).standardizedFileURL
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard target.path.hasPrefix(prefix) else {
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

    /// Removes every file under one relative directory (Reset Analysis).
    /// Absent directory counts as success; failures on individual files are
    /// ignored so one bad file never blocks the reset.
    func removeDirectory(relativePath: String) {
        guard let target = try? url(for: relativePath) else { return }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: target, includingPropertiesForKeys: nil
        ) else { return }
        for item in items {
            try? FileManager.default.removeItem(at: item)
        }
    }

    func exists(relativePath: String) -> Bool {
        guard let target = try? url(for: relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: target.path)
    }

    /// Lists JSON filenames (no directories) under one relative directory.
    /// Missing directory returns []. Never throws: resume probing must not fail launch.
    func listJSONFiles(under relativePath: String) -> [String] {
        listJSONFilesWithAvailability(under: relativePath).files
    }

    /// Lists JSON filenames while distinguishing an absent directory from a
    /// directory that exists but cannot be inspected. Recovery surfaces use
    /// this result so an I/O failure is not presented as an empty saved-work
    /// store.
    func listJSONFilesWithAvailability(under relativePath: String) -> JSONFileListing {
        guard let target = try? url(for: relativePath) else {
            return JSONFileListing(files: [], isAvailable: false)
        }
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) else {
            return JSONFileListing(files: [], isAvailable: true)
        }
        guard isDirectory.boolValue,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: target, includingPropertiesForKeys: [.contentModificationDateKey]
              )
        else {
            return JSONFileListing(files: [], isAvailable: false)
        }
        return JSONFileListing(
            files: items
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent },
            isAvailable: true
        )
    }
}
