import Foundation

/// Persisted cache envelope. Rows written before revision-aware caching were
/// plain PhotoAnalysis values; the tolerant decoder recognizes those rows and
/// marks them legacy so they remain readable but can only be cache misses.
private struct CachedAnalysisRecord: Codable, Sendable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let analysis: PhotoAnalysis
    let assetRevision: AssetModificationFingerprint?

    init(analysis: PhotoAnalysis, assetRevision: AssetModificationFingerprint) {
        schemaVersion = Self.currentSchemaVersion
        self.analysis = analysis
        self.assetRevision = assetRevision
    }

    init(from decoder: Decoder) throws {
        if let legacy = try? PhotoAnalysis(from: decoder) {
            schemaVersion = 0
            analysis = legacy
            assetRevision = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        analysis = try container.decode(PhotoAnalysis.self, forKey: .analysis)
        assetRevision = try container.decodeIfPresent(AssetModificationFingerprint.self, forKey: .assetRevision)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, analysis, assetRevision
    }
}

/// File-backed AnalysisCache. Holds compact derived values only, never image
/// blobs. Revision-aware callers must match both analysis version and the
/// PhotoKit modification fingerprint before a row is reused.
actor FileAnalysisCache: AnalysisCache {
    private let files: FileStore
    private let analysisVersion: Int
    private let directory: String
    private var memory: [AssetID: CachedAnalysisRecord] = [:]

    init(files: FileStore, analysisVersion: Int, directory: String = "analysis-cache") {
        self.files = files
        self.analysisVersion = analysisVersion
        self.directory = directory
    }

    private func path(for id: AssetID) -> String {
        let safe = id.rawValue.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "unknown"
        return "\(directory)/\(safe).json"
    }

    func analysis(for id: AssetID) async -> PhotoAnalysis? {
        // Source-compatible read for older consumers that have only an ID.
        // It never accepts legacy rows or a row with no revision, but cannot
        // compare the revision until the caller supplies the live asset.
        guard let record = await record(for: id), isReusableVersion(record) else {
            return nil
        }
        return record.analysis
    }

    func analysis(for id: AssetID, assetRevision: AssetModificationFingerprint) async -> PhotoAnalysis? {
        guard let record = await record(for: id),
              record.schemaVersion == CachedAnalysisRecord.currentSchemaVersion,
              record.analysis.assetID == id,
              record.analysis.analysisVersion == analysisVersion,
              record.assetRevision == assetRevision
        else {
            return nil
        }
        return record.analysis
    }

    func store(_ analysis: PhotoAnalysis) async {
        // The old API has no live revision and must not create a reusable row.
        // Keep it a no-op rather than persisting facts that cannot be validated.
    }

    func store(_ analysis: PhotoAnalysis, assetRevision: AssetModificationFingerprint) async {
        guard analysis.analysisVersion == analysisVersion else {
            return
        }
        let record = CachedAnalysisRecord(analysis: analysis, assetRevision: assetRevision)
        memory[analysis.assetID] = record
        // Best effort: retain memory on transient I/O failure rather than forcing re-analysis.
        try? await files.save(record, to: path(for: analysis.assetID))
    }

    private func record(for id: AssetID) async -> CachedAnalysisRecord? {
        if let cached = memory[id] {
            return cached
        }
        guard let loaded: CachedAnalysisRecord = try? await files.load(
            CachedAnalysisRecord.self,
            from: path(for: id)
        ) else {
            return nil
        }
        memory[id] = loaded
        return loaded
    }

    private func isReusableVersion(_ record: CachedAnalysisRecord) -> Bool {
        record.schemaVersion == CachedAnalysisRecord.currentSchemaVersion
            && record.analysis.analysisVersion == analysisVersion
            && record.assetRevision != nil
    }

    /// Reset Analysis: drops in-memory rows plus every persisted analysis
    /// file. Originals in Apple Photos are untouched.
    func reset() async {
        memory = [:]
        await files.removeDirectory(relativePath: directory)
    }
}
