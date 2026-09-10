import Foundation

/// File-backed AnalysisCache skeleton. Conforms to the G0 AnalysisCache protocol.
/// Reuses an entry only when the stored analysisVersion matches the current version.
/// Fingerprint comparison against live PhotoAsset metadata arrives with feat-003A.
/// Holds compact PhotoAnalysis values only, never image blobs.
actor FileAnalysisCache: AnalysisCache {
    private let files: FileStore
    private let analysisVersion: Int
    private let directory: String
    private var memory: [AssetID: PhotoAnalysis] = [:]

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
        if let cached = memory[id] {
            guard cached.analysisVersion == analysisVersion else {
                memory[id] = nil
                return nil
            }
            return cached
        }
        guard let loaded: PhotoAnalysis = try? await files.load(PhotoAnalysis.self, from: path(for: id)) else {
            return nil
        }
        guard loaded.analysisVersion == analysisVersion else {
            memory[id] = nil
            return nil
        }
        memory[id] = loaded
        return loaded
    }

    func store(_ analysis: PhotoAnalysis) async {
        guard analysis.analysisVersion == analysisVersion else {
            return
        }
        memory[analysis.assetID] = analysis
        // Best effort: retain memory on transient I/O failure rather than forcing re-analysis.
        try? await files.save(analysis, to: path(for: analysis.assetID))
    }
}
