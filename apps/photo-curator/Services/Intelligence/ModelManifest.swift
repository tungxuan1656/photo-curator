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
                sha256: "881551e657df505cc60895011213c9eef75ceb438b1958c71100324e32a12edf"
            ),
            .init(
                path: "config.json", byteCount: 3113,
                sha256: "25a55c5ad15a39565d100f27951c0f315e81195203e5ac8058dab53f32fc6234"
            ),
            .init(
                path: "model.safetensors", byteCount: 1_722_271_785,
                sha256: "713fe7e5d3c3965f7106b0d0ee17615f7869c23c8d327996df8c1196fbcf07d"
            ),
            .init(
                path: "model.safetensors.index.json", byteCount: 81722,
                sha256: "f98668e3c4f6b10c71a8c0a0e125f7b1bed762bc57f6ded6191a1440d42fe8c3"
            ),
            .init(
                path: "preprocessor_config.json", byteCount: 390,
                sha256: "28d900ccac323ac5ec852bb44bd249a1c49760fea4b83a4d6a68168c87a6333b"
            ),
            .init(
                path: "processor_config.json", byteCount: 1300,
                sha256: "4618e8b1e6d70962fc22a9d0c5513bed5f5f59947d140f5313595b609bb33d71"
            ),
            .init(
                path: "tokenizer.json", byteCount: 19_989_343,
                sha256: "7f65ee19ad4df5313fb24988b0843787dd3b3e3e9c64789228d503ff761e2805"
            ),
            .init(
                path: "tokenizer_config.json", byteCount: 1139,
                sha256: "0e034f8b2d8b80d251154cb38aa422e6728ca1d378ab7405d950c5a774aab656"
            ),
            .init(
                path: "video_preprocessor_config.json", byteCount: 385,
                sha256: "6dc463a837f46be1b9c56675e4ac21c4c6f1367ea6a04aa16555c8b67a122e87"
            ),
            .init(
                path: "vocab.json", byteCount: 6_722_759,
                sha256: "abe987a1126d8abf43481b0186e107e087d21a0ca1a7266ca97b47eed8988475"
            ),
        ]
    )

    nonisolated func validate(at directory: URL) throws {
        for file in files {
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
