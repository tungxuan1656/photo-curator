import Foundation

/// Small resumable manifest. No image bytes, no face data, no pixels.
/// Stage stays an opaque label here; typed ProcessingStage mapping arrives with the coordinator.
/// nonisolated: the app target defaults to MainActor isolation, which would isolate the Codable
/// conformance and block use across actors.
nonisolated struct SessionCheckpoint: Codable, Sendable {
    let sessionID: SessionID
    let stage: String
    let completedAssetIDs: [AssetID]
    let sourceAssetIDs: [AssetID]
    let configVersion: Int
    let analysisVersion: Int
    let updatedAt: Date

    /// Explicit init so pre-006 call sites keep compiling: sourceAssetIDs defaults to [].
    init(
        sessionID: SessionID,
        stage: String,
        completedAssetIDs: [AssetID],
        sourceAssetIDs: [AssetID] = [],
        configVersion: Int,
        analysisVersion: Int,
        updatedAt: Date
    ) {
        self.sessionID = sessionID
        self.stage = stage
        self.completedAssetIDs = completedAssetIDs
        self.sourceAssetIDs = sourceAssetIDs
        self.configVersion = configVersion
        self.analysisVersion = analysisVersion
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case sessionID
        case stage
        case completedAssetIDs
        case sourceAssetIDs
        case configVersion
        case analysisVersion
        case updatedAt
    }

    /// Version-tolerant decode: pre-006 manifests lack `sourceAssetIDs`, which defaults to [].
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(SessionID.self, forKey: .sessionID)
        stage = try container.decode(String.self, forKey: .stage)
        completedAssetIDs = try container.decode([AssetID].self, forKey: .completedAssetIDs)
        sourceAssetIDs = try container.decodeIfPresent([AssetID].self, forKey: .sourceAssetIDs) ?? []
        configVersion = try container.decode(Int.self, forKey: .configVersion)
        analysisVersion = try container.decode(Int.self, forKey: .analysisVersion)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(stage, forKey: .stage)
        try container.encode(completedAssetIDs, forKey: .completedAssetIDs)
        try container.encode(sourceAssetIDs, forKey: .sourceAssetIDs)
        try container.encode(configVersion, forKey: .configVersion)
        try container.encode(analysisVersion, forKey: .analysisVersion)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// File-backed checkpoint skeleton. Wired in AppContainer.live() in feat-002.
actor SessionCheckpointStore {
    private let files: FileStore
    private let directory: String
    private let resultsDirectory = "results"
    /// Session generations (DEC-046): every `reopenSession` mints a newer
    /// UInt64 owner; every feedback save captures the generation live at its
    /// hook-install time. The actor applies a save only when its captured
    /// generation still equals the session's current generation at apply
    /// time. Delete paths bump the generation past every captured writer, so
    /// an old-session PersistLatest/Task queued before cleanup and flushed
    /// after a same-process reopen still drops instead of writing into the
    /// new session. Tombstones (`closedSessions`) keep covering process-wide
    /// close; generations cover same-process reopen. Live re-entry
    /// (`beginReview`) mints the new owner via `reopenSession`.
    private var closedSessions: Set<SessionID> = []
    private var sessionGenerations: [SessionID: UInt64] = [:]
    private var generationCounter: UInt64 = 0

    init(files: FileStore, directory: String = "checkpoints") {
        self.files = files
        self.directory = directory
    }

    private func path(for sessionID: SessionID) -> String {
        "\(directory)/\(sessionID.rawValue.uuidString).json"
    }

    private func resultPath(for sessionID: SessionID) -> String {
        "\(resultsDirectory)/\(sessionID.rawValue.uuidString).json"
    }

    private func feedbackPath(for sessionID: SessionID) -> String {
        "feedback/\(sessionID.rawValue.uuidString).json"
    }

    private func saveStatePath(for sessionID: SessionID) -> String {
        "savestate/\(sessionID.rawValue.uuidString).json"
    }

    private func uncertaintyFeedbackPath(for sessionID: SessionID) -> String {
        "uncertainty-feedback/\(sessionID.rawValue.uuidString).json"
    }

    func save(_ checkpoint: SessionCheckpoint) async throws {
        try await files.save(checkpoint, to: path(for: checkpoint.sessionID))
    }

    func load(sessionID: SessionID) async throws -> SessionCheckpoint {
        try await files.load(SessionCheckpoint.self, from: path(for: sessionID))
    }

    func delete(sessionID: SessionID) async throws {
        do {
            try await files.remove(relativePath: path(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    func saveResult(_ result: SelectionResult) async throws {
        try await files.save(result, to: resultPath(for: result.sessionID))
    }

    func loadResult(sessionID: SessionID) async throws -> SelectionResult {
        try await files.load(SelectionResult.self, from: resultPath(for: sessionID))
    }

    func deleteResult(sessionID: SessionID) async throws {
        do {
            try await files.remove(relativePath: resultPath(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    /// Dropped (success, no write) once the session closes or its generation
    /// moves on: late hook writes must not resurrect rows after cleanup, and
    /// stale old-session writers must not enter a reopened session (DEC-046).
    /// Ordinary save failure still throws, so the caller retries on the next
    /// mutation (DEC-043).
    func saveFeedback(_ feedback: SelectionFeedback, for sessionID: SessionID) async throws {
        try await saveFeedback(feedback, for: sessionID, generation: sessionGenerations[sessionID])
    }

    /// Generation-pinned write: applies only when `generation` still equals
    /// the session's current generation at apply time (nil matches only an
    /// unopened session that was never deleted — a tombstoned session drops).
    func saveFeedback(_ feedback: SelectionFeedback, for sessionID: SessionID, generation: UInt64?) async throws {
        guard !closedSessions.contains(sessionID), sessionGenerations[sessionID] == generation else { return }
        try await files.save(feedback, to: feedbackPath(for: sessionID))
    }

    /// Current owner for hook-install capture. Prefer the generation returned
    /// by `reopenSession` (mint + read in one actor call, no reopen/read
    /// race); this accessor covers read-only callers.
    func feedbackGeneration(for sessionID: SessionID) -> UInt64? {
        sessionGenerations[sessionID]
    }

    /// Missing or unreadable feedback means a fresh session: nil, never a throw.
    func loadFeedback(sessionID: SessionID) async -> SelectionFeedback? {
        try? await files.load(SelectionFeedback.self, from: feedbackPath(for: sessionID))
    }

    /// Deletes the row; tombstones the session first so late hook writes
    /// drop instead of recreating it (DEC-043). Absent counts as success.
    func deleteFeedback(sessionID: SessionID) async throws {
        retireSession(sessionID)
        do {
            try await files.remove(relativePath: feedbackPath(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    /// Bounded review snapshot: aggregate reason counts only, never photo
    /// identifiers, pixels, or face data (DEC-042). Missing/unreadable rows
    /// (absent, corrupt, schema-version mismatch) mean a fresh session: nil,
    /// never a throw — same rule as `loadFeedback`. Closed or
    /// generation-retired sessions drop writes (DEC-043/DEC-046).
    func saveUncertaintyFeedback(_ snapshot: UncertaintyFeedbackSnapshot, for sessionID: SessionID) async throws {
        try await saveUncertaintyFeedback(snapshot, for: sessionID, generation: sessionGenerations[sessionID])
    }

    /// Generation-pinned write: same drop rule as the feedback pair above.
    func saveUncertaintyFeedback(
        _ snapshot: UncertaintyFeedbackSnapshot, for sessionID: SessionID, generation: UInt64?
    ) async throws {
        guard !closedSessions.contains(sessionID), sessionGenerations[sessionID] == generation else { return }
        try await files.save(snapshot, to: uncertaintyFeedbackPath(for: sessionID))
    }

    func loadUncertaintyFeedback(sessionID: SessionID) async -> UncertaintyFeedbackSnapshot? {
        guard let snapshot: UncertaintyFeedbackSnapshot = try? await files.load(
            UncertaintyFeedbackSnapshot.self, from: uncertaintyFeedbackPath(for: sessionID)
        ), snapshot.schemaVersion == UncertaintyFeedbackSnapshot.schemaVersion else {
            return nil
        }
        return snapshot
    }

    func deleteUncertaintyFeedback(sessionID: SessionID) async throws {
        retireSession(sessionID)
        do {
            try await files.remove(relativePath: uncertaintyFeedbackPath(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    /// Retires one session: tombstones it AND bumps the generation past every
    /// captured writer, so stale old-session writes cannot enter a reopened
    /// session (DEC-046). Called from every feedback-delete path.
    private func retireSession(_ sessionID: SessionID) {
        closedSessions.insert(sessionID)
        generationCounter += 1
        sessionGenerations[sessionID] = generationCounter
    }

    /// Tombstones one session so late feedback Tasks drop instead of
    /// recreating rows. Called from every feedback-delete path.
    func closeSession(_ sessionID: SessionID) {
        retireSession(sessionID)
    }

    /// Live re-entry: clears the tombstone AND mints a new generation owner,
    /// returned for hook-install capture in the same statement (no
    /// reopen/read race with a concurrent delete). Never called from a
    /// delete path (DEC-043).
    @discardableResult
    func reopenSession(_ sessionID: SessionID) -> UInt64? {
        closedSessions.remove(sessionID)
        generationCounter += 1
        sessionGenerations[sessionID] = generationCounter
        return sessionGenerations[sessionID]
    }

    func saveSaveState(_ state: SaveState) async throws {
        try await files.save(state, to: saveStatePath(for: state.sessionID))
    }

    /// No persisted save means no save in flight: nil, never a throw.
    func loadSaveState(sessionID: SessionID) async -> SaveState? {
        try? await files.load(SaveState.self, from: saveStatePath(for: sessionID))
    }

    func deleteSaveState(sessionID: SessionID) async throws {
        do {
            try await files.remove(relativePath: saveStatePath(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    /// Cold-start resume probe: newest decodable checkpoint plus presence of its
    /// result and save-state siblings. Missing/corrupt files are skipped, never thrown.
    struct ResumableSession: Sendable {
        let checkpoint: SessionCheckpoint
        let hasResult: Bool
        let hasSaveState: Bool
    }

    func latestCheckpoint() async -> ResumableSession? {
        let ids = await files.listJSONFiles(under: directory)
        var best: (SessionCheckpoint, Date)?
        for raw in ids {
            guard let uuid = UUID(uuidString: raw) else { continue }
            let id = SessionID(rawValue: uuid)
            guard let checkpoint = try? await files.load(SessionCheckpoint.self, from: path(for: id)) else { continue }
            if best == nil || checkpoint.updatedAt > best!.0.updatedAt {
                best = (checkpoint, checkpoint.updatedAt)
            }
        }
        guard let found = best?.0 else { return nil }
        let hasResult = (try? await files.load(SelectionResult.self, from: resultPath(for: found.sessionID))) != nil
        let hasSave = await loadSaveState(sessionID: found.sessionID) != nil
        return ResumableSession(checkpoint: found, hasResult: hasResult, hasSaveState: hasSave)
    }
}
