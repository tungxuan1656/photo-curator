import Foundation

/// Deterministic uncertainty contract (feat-026, DEC-042).
///
/// Derives a small actionable Needs Review queue from persisted feat-023
/// `Decision` outputs only (reason codes per selection-rules §16 plus the
/// optional score). No new signals, no analysis reads, no cluster/moment
/// objects: review-time derivation over already-persisted decisions, so
/// deterministic decisions keep the existing S10/S12/S13 flow untouched.
///
/// Ownership: thresholds live here as policy constants (no new
/// `SelectionConfiguration` keys, per the selection-rules §17 small-knob
/// precedent set by feat-023/024). Frozen values: `scoreMargin` 0.05,
/// `maxItems` 30. Change them only with a new DEC entry and re-proof.
enum UncertaintyReason: String, Codable, Sendable, CaseIterable {
    /// Kept photo whose score sits just above the quality floor.
    case borderlineQuality
    /// Group pick where face signals decided the winner.
    case faceTradeoff
    /// Pick speaking for near-duplicates the user may prefer differently.
    case similarAlternatives
    /// Distinct second view of one moment; both survive only when distinct.
    case secondMomentView
    /// Usable photo cut for variety whose score nearly kept it.
    case coverageCut

    /// Queue order: quality risk first, close cuts last.
    var priority: Int {
        switch self {
        case .borderlineQuality: 0
        case .faceTradeoff: 1
        case .similarAlternatives: 2
        case .secondMomentView: 3
        case .coverageCut: 4
        }
    }

    /// Fixed action vocabulary: each maps to an existing review surface.
    var action: UncertaintyAction {
        switch self {
        case .borderlineQuality: .inspectDetail
        case .faceTradeoff: .inspectDetail
        case .similarAlternatives: .viewSimilar
        case .secondMomentView: .compareMoment
        case .coverageCut: .considerAddBack
        }
    }
}

/// Fixed action vocabulary for queue items. Each maps to an existing
/// review surface (S10/S11/S21, S12, S13); no new selection behavior.
enum UncertaintyAction: String, Codable, Sendable {
    /// Open the photo detail (S11) and analysis (S21).
    case inspectDetail
    /// Open Similar Photos (S12) to compare alternatives.
    case viewSimilar
    /// Compare both moment views in detail (S11).
    case compareMoment
    /// Find the photo in Removed (S13) and add it back if it matters.
    case considerAddBack
}

/// One queued photo: transient review state only, never persisted.
/// `order` is the decision index (source order) for deterministic ties.
struct NeedsReviewItem: Hashable, Sendable {
    let assetID: AssetID
    let reason: UncertaintyReason
    let action: UncertaintyAction
    let order: Int
}

/// Pure queue derivation over persisted decisions.
enum UncertaintyClassifier: Sendable {
    /// Score band: a kept photo within this margin above the quality floor
    /// reads as borderline; a cut photo within this margin below the weakest
    /// keep reads as a close call.
    static let scoreMargin = 0.05
    /// Bounded queue: at most this many items in (priority, source-order).
    static let maxItems = 30

    /// Rejected diversity-cut reasons eligible for the close-call queue.
    nonisolated static func isCoverageCutReason(_ reason: String) -> Bool {
        reason == "temporalCoverage" || reason == "sceneDiversity" || reason == "peopleDiversity"
            || reason == "compositionDiversity" || reason == "meaningfulVariation"
    }

    /// Deterministic: same decisions + threshold give the same queue.
    /// `assetUnavailable`/eligibility/floor/duplicate-loser decisions never
    /// queue (the unavailable bucket and deterministic rules own them).
    static func queue(
        decisions: [Decision],
        lowQualityThreshold: Double,
        maxItems: Int = UncertaintyClassifier.maxItems
    ) -> [NeedsReviewItem] {
        let selectedScores = decisions
            .filter { $0.status == .selected }
            .compactMap(\.score)
        let weakestKeep = selectedScores.min()
        var items: [NeedsReviewItem] = []
        for (order, decision) in decisions.enumerated() {
            if let item = classify(
                decision,
                order: order,
                lowQualityThreshold: lowQualityThreshold,
                weakestKeep: weakestKeep
            ) {
                items.append(item)
            }
        }
        items.sort {
            if $0.reason.priority != $1.reason.priority {
                return $0.reason.priority < $1.reason.priority
            }
            if $0.order != $1.order {
                return $0.order < $1.order
            }
            return $0.assetID.rawValue < $1.assetID.rawValue
        }
        return Array(items.prefix(maxItems))
    }

    private static func classify(
        _ decision: Decision,
        order: Int,
        lowQualityThreshold: Double,
        weakestKeep: Double?
    ) -> NeedsReviewItem? {
        let reasons = Set(decision.reasons)
        let unavailable = reasons.contains("assetUnavailable") || reasons.contains("unsupportedAsset")
            || reasons.contains("corruptedAsset")
        guard !unavailable else { return nil }
        if decision.status == .selected {
            return classifyKeep(decision, order: order, lowQualityThreshold: lowQualityThreshold)
        }
        return classifyCut(decision, order: order, weakestKeep: weakestKeep)
    }

    private static func classifyKeep(
        _ decision: Decision,
        order: Int,
        lowQualityThreshold: Double
    ) -> NeedsReviewItem? {
        let reasons = Set(decision.reasons)
        if let score = decision.score, score < lowQualityThreshold + scoreMargin {
            return NeedsReviewItem(
                assetID: decision.assetID,
                reason: .borderlineQuality,
                action: UncertaintyReason.borderlineQuality.action,
                order: order
            )
        }
        if reasons.contains("bestGroupPhoto") {
            return NeedsReviewItem(
                assetID: decision.assetID,
                reason: .faceTradeoff,
                action: UncertaintyReason.faceTradeoff.action,
                order: order
            )
        }
        if reasons.contains("nearDuplicateRepresentative") {
            return NeedsReviewItem(
                assetID: decision.assetID,
                reason: .similarAlternatives,
                action: UncertaintyReason.similarAlternatives.action,
                order: order
            )
        }
        if reasons.contains("secondaryMomentRepresentative") {
            return NeedsReviewItem(
                assetID: decision.assetID,
                reason: .secondMomentView,
                action: UncertaintyReason.secondMomentView.action,
                order: order
            )
        }
        return nil
    }

    private static func classifyCut(
        _ decision: Decision,
        order: Int,
        weakestKeep: Double?
    ) -> NeedsReviewItem? {
        guard decision.reasons.contains(where: isCoverageCutReason) else { return nil }
        guard let score = decision.score, let weakest = weakestKeep,
              score + scoreMargin >= weakest
        else { return nil }
        return NeedsReviewItem(
            assetID: decision.assetID,
            reason: .coverageCut,
            action: UncertaintyReason.coverageCut.action,
            order: order
        )
    }
}

/// Session review state for the queue: derived items plus resolution against
/// the persisted edit sets. Single source of truth for queue derivation,
/// resolution, and snapshot (feat-026, DEC-042): `ReviewModel` holds one and
/// delegates, never reimplements. Derived once per review entry; resolution
/// recomputes from the live `SelectionFeedback`.
struct UncertaintyReviewState: Sendable {
    let items: [NeedsReviewItem]

    init(
        result: SelectionResult,
        lowQualityThreshold: Double,
        maxItems: Int = UncertaintyClassifier.maxItems
    ) {
        self.init(
            decisions: result.decisions,
            lowQualityThreshold: lowQualityThreshold,
            maxItems: maxItems
        )
    }

    /// Live-filtered entry: `ReviewModel` passes decisions already scoped to
    /// resolvable source assets.
    init(
        decisions: [Decision],
        lowQualityThreshold: Double,
        maxItems: Int = UncertaintyClassifier.maxItems
    ) {
        items = UncertaintyClassifier.queue(
            decisions: decisions,
            lowQualityThreshold: lowQualityThreshold,
            maxItems: maxItems
        )
    }

    /// True once the user edits a queued photo (remove, restore, swap winner).
    /// Call for queue members; the snapshot intersects with queue IDs anyway.
    func isResolved(_ id: AssetID, feedback: SelectionFeedback) -> Bool {
        feedback.removedIDs.contains(id)
            || feedback.restoredIDs.contains(id)
            || feedback.swapWinner.values.contains(id)
    }

    func resolvedCount(feedback: SelectionFeedback) -> Int {
        items.filter { isResolved($0.assetID, feedback: feedback) }.count
    }

    func snapshot(
        sessionID: SessionID,
        engineVersion: Int,
        feedback: SelectionFeedback,
        updatedAt: Date
    ) -> UncertaintyFeedbackSnapshot {
        let queueIDs = Set(items.map(\.assetID))
        let edits = feedback.removedIDs
            .union(feedback.restoredIDs)
            .union(Set(feedback.swapWinner.values))
        return UncertaintyFeedbackSnapshot.derive(
            sessionID: sessionID,
            engineVersion: engineVersion,
            items: items,
            resolvedIDs: edits.intersection(queueIDs),
            updatedAt: updatedAt
        )
    }
}

/// Bounded on-device feedback capture (feat-026, DEC-042): aggregate counts
/// only. Never carries image bytes, face data, embeddings, GPS, full EXIF,
/// asset identifiers, or free text — reason keys use the fixed
/// `UncertaintyReason` vocabulary and `sessionID` is the existing ephemeral
/// per-run ID (analytics §2). Strict seven-key read (DEC-044): unknown or
/// missing top-level keys decode-throw, so the store loads nil (fresh).
nonisolated struct UncertaintyFeedbackSnapshot: Codable, Sendable {
    nonisolated static let schemaVersion = 1
    /// DEC-044 exact seven-key freeze: schemaVersion/sessionID/engineVersion/
    /// queueSize/resolvedByReason/totalResolved/updatedAt only. Synthesized
    /// Codable ignores unknown top-level keys, so the custom decoder below
    /// rejects configVersion or any other extra key with nil-on-read.
    static let exactKeys: Set<String> = Set(StrictKeys.allCases.map(\.rawValue))

    enum StrictKeys: String, CodingKey, CaseIterable {
        case schemaVersion, sessionID, engineVersion, queueSize
        case resolvedByReason, totalResolved, updatedAt
    }

    /// Open key type for strict enumeration only (never a stored shape).
    struct OpenKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    let schemaVersion: Int
    let sessionID: SessionID
    let engineVersion: Int
    let queueSize: Int
    let resolvedByReason: [String: Int]
    let totalResolved: Int
    let updatedAt: Date

    init(
        schemaVersion: Int,
        sessionID: SessionID,
        engineVersion: Int,
        queueSize: Int,
        resolvedByReason: [String: Int],
        totalResolved: Int,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.engineVersion = engineVersion
        self.queueSize = queueSize
        self.resolvedByReason = resolvedByReason
        self.totalResolved = totalResolved
        self.updatedAt = updatedAt
    }

    /// Derives counts from queue membership only; edits outside the queue
    /// never inflate the record.
    static func derive(
        sessionID: SessionID,
        engineVersion: Int,
        items: [NeedsReviewItem],
        resolvedIDs: Set<AssetID>,
        updatedAt: Date
    ) -> UncertaintyFeedbackSnapshot {
        let queueIDs = Set(items.map(\.assetID))
        let resolved = resolvedIDs.intersection(queueIDs)
        var byReason: [String: Int] = [:]
        for item in items where resolved.contains(item.assetID) {
            byReason[item.reason.rawValue, default: 0] += 1
        }
        return UncertaintyFeedbackSnapshot(
            schemaVersion: schemaVersion,
            sessionID: sessionID,
            engineVersion: engineVersion,
            queueSize: items.count,
            resolvedByReason: byReason,
            totalResolved: resolved.count,
            updatedAt: updatedAt
        )
    }

    init(from decoder: Decoder) throws {
        // Strict read: `container(keyedBy: StrictKeys.self).allKeys` hides
        // unknown keys by design, so enumerate via an open key type first.
        let open = try decoder.container(keyedBy: OpenKey.self)
        let seen = Set(open.allKeys.map(\.stringValue))
        guard seen == Self.exactKeys else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "strict seven-key snapshot, got \(seen.sorted())"
            ))
        }
        let raw = try decoder.container(keyedBy: StrictKeys.self)
        let schemaVersion = try raw.decode(Int.self, forKey: .schemaVersion)
        let sessionID = try raw.decode(SessionID.self, forKey: .sessionID)
        let engineVersion = try raw.decode(Int.self, forKey: .engineVersion)
        let queueSize = try raw.decode(Int.self, forKey: .queueSize)
        let resolvedByReason = try raw.decode([String: Int].self, forKey: .resolvedByReason)
        let totalResolved = try raw.decode(Int.self, forKey: .totalResolved)
        let updatedAt = try raw.decode(Date.self, forKey: .updatedAt)
        self.init(
            schemaVersion: schemaVersion, sessionID: sessionID, engineVersion: engineVersion,
            queueSize: queueSize, resolvedByReason: resolvedByReason,
            totalResolved: totalResolved, updatedAt: updatedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StrictKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(engineVersion, forKey: .engineVersion)
        try container.encode(queueSize, forKey: .queueSize)
        try container.encode(resolvedByReason, forKey: .resolvedByReason)
        try container.encode(totalResolved, forKey: .totalResolved)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
