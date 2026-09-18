import CryptoKit
import Foundation

// SwiftFormat's repository-wide comma policy conflicts with SwiftLint for this literal.
// swiftlint:disable trailing_comma

struct ModelArtifactFile: Codable, Hashable, Sendable {
    let path: String
    let byteCount: Int64
    let sha256: String
}

enum ModelManifestError: Error, Sendable {
    case invalidPath(String)
    case missingFile(String)
    case unexpectedFile(String)
    case sizeMismatch(String)
    case digestMismatch(String)
}

struct ModelManifest: Codable, Sendable {
    let schemaVersion: Int
    let modelID: String
    let revision: String
    let runtimeRevision: String
    let license: String
    let files: [ModelArtifactFile]

    nonisolated static let qwen35TwoBFourBit = Self(
        schemaVersion: 1,
        modelID: "mlx-community/Qwen3.5-2B-4bit",
        revision: "674aaa7240b91e8012fcad5d791b7dfe5ba90207",
        runtimeRevision: "c6446cf7bfb7cea76408013b614d4b2c530eaa03",
        license: "Apache-2.0",
        files: [
            .init(
                path: "chat_template.jinja", byteCount: 7755,
                sha256: "273d8e0e683b885071fb17e08d71e5f2a5ddfb5309756181681de4f5a1822d80"
            ),
            .init(
                path: "config.json", byteCount: 3113,
                sha256: "beb7fc5a6e0405fe332821cf1a8ef7b69bb390a8c8933171647de5579debf949"
            ),
            .init(
                path: "model.safetensors", byteCount: 1_722_271_785,
                sha256: "713fe7e5d3c3965f7106b0d0ee17615f7869c23c8d327996df8c1196fbcf07d5"
            ),
            .init(
                path: "model.safetensors.index.json", byteCount: 81722,
                sha256: "8294c05cca7d53a6c33e3db2b379539bd296d054e0b689711b16b6ac93c7e49d"
            ),
            .init(
                path: "preprocessor_config.json", byteCount: 390,
                sha256: "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516"
            ),
            .init(
                path: "processor_config.json", byteCount: 1300,
                sha256: "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b"
            ),
            .init(
                path: "tokenizer.json", byteCount: 19_989_343,
                sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"
            ),
            .init(
                path: "tokenizer_config.json", byteCount: 1139,
                sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"
            ),
            .init(
                path: "video_preprocessor_config.json", byteCount: 385,
                sha256: "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13"
            ),
            .init(
                path: "vocab.json", byteCount: 6_722_759,
                sha256: "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003"
            ),
        ]
    )

    var totalByteCount: Int64 {
        files.reduce(0) { $0 + $1.byteCount }
    }

    nonisolated func validate(at directory: URL) throws {
        for file in files {
            try validate(file: file, at: directory)
        }

        let expected = Set(files.map(\.path))
        let actual = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]
        ).compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true else {
                return nil
            }
            return url.lastPathComponent
        }
        for path in Set(actual).subtracting(expected) {
            throw ModelManifestError.unexpectedFile(path)
        }
    }

    nonisolated func validate(file: ModelArtifactFile, at directory: URL) throws {
        guard isSafeRelativePath(file.path) else {
            throw ModelManifestError.invalidPath(file.path)
        }

        let url = directory.appending(path: file.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ModelManifestError.missingFile(file.path)
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              Int64(fileSize) == file.byteCount
        else {
            throw ModelManifestError.sizeMismatch(file.path)
        }
        guard try digest(of: url) == file.sha256 else {
            throw ModelManifestError.digestMismatch(file.path)
        }
    }

    private nonisolated func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.split(separator: "/").contains("..")
    }

    private nonisolated func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// swiftlint:enable trailing_comma
