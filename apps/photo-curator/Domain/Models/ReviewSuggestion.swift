import Foundation

/// Minimum review-facing suggestion contract (feat-034 owner).
/// Immutable advisory records derived from existing native analysis/grouping
/// outputs. Never mutate user choices; application requires explicit preview
/// plus confirmation through `ReviewModel`. No feat-037 dependency.
enum ReviewSuggestionProvenance: String, Codable, Sendable {
    case native
    case legacyNativeAdapter
}

enum ReviewSuggestionEvidence: String, Codable, Sendable {
    case available
    case insufficient
    case unavailable
}

/// One choice dimension plus per-asset values. Deletion staging is never
/// expressible here; cleanup proposals carry keep-only sets.
enum ReviewSuggestionProposal: Sendable {
    case albumMembership([AssetID: AlbumMembership])
    case cleanupKeep(Set<AssetID>)
}

/// Owner-copy keys for suggestion display. Views resolve them as
/// `LocalizedStringResource` so en/vi come from the catalog.
enum ReviewSuggestionCopy {
    static let advisoryNote = "The app suggested this. You decide."
    static let useSuggestion = "Use Suggestion"
    static let keepMyChoice = "Keep My Choice"
    static let previewTitle = "Review Suggested Changes"
    static let applyTitle = "Apply These Changes"
    static let changedNotice = "This suggestion changed. Review it again."
    static let evidenceAvailable = "Suggestion available"
    static let evidenceInsufficient = "Not enough information for a suggestion"
    static let evidenceUnavailable = "Analysis unavailable"
    static let albumDimension = "Album membership"
    static let cleanupDimension = "Cleanup choice"
    static let albumUnset = "Not chosen for album"
    static let albumIncluded = "In album"
    static let albumExcluded = "Excluded from album"
    static let cleanupUndecided = "Undecided"
    static let cleanupKeep = "Keep"
    static let cleanupStaged = "Staged for deletion"
}

struct ReviewSuggestionPreviewRow: Sendable, Identifiable {
    let id: String
    let dimension: String
    let oldValue: String
    let newValue: String
}

struct ReviewSuggestion: Sendable, Identifiable {
    let id: UUID
    let scopeID: UUID
    let candidateIDs: [AssetID]
    let groupID: ClusterID?
    let analysisVersion: Int?
    let engineVersion: Int
    let sourceRevision: String
    let provenance: ReviewSuggestionProvenance
    let evidence: ReviewSuggestionEvidence
    let proposal: ReviewSuggestionProposal?

    /// Gated: only available records with a complete proposal and a stable
    /// revision enable Use Suggestion. Anything else renders as
    /// unavailable/insufficient copy.
    var canUse: Bool {
        guard evidence == .available, proposal != nil else { return false }
        guard analysisVersion != nil else { return false }
        return true
    }

    /// Exact IDs plus one dimension and its per-asset values, using owner
    /// copy keys so both languages resolve from the catalog.
    var previewRows: [ReviewSuggestionPreviewRow] {
        switch proposal {
        case let .albumMembership(values):
            return values.map { assetID, membership in
                let newValue: String = switch membership {
                case .unset: ReviewSuggestionCopy.albumUnset
                case .included: ReviewSuggestionCopy.albumIncluded
                case .excluded: ReviewSuggestionCopy.albumExcluded
                }
                return ReviewSuggestionPreviewRow(
                    id: assetID.rawValue,
                    dimension: ReviewSuggestionCopy.albumDimension,
                    oldValue: ReviewSuggestionCopy.albumUnset,
                    newValue: newValue
                )
            }.sorted { $0.id < $1.id }
        case let .cleanupKeep(ids):
            return ids.map { assetID in
                ReviewSuggestionPreviewRow(
                    id: assetID.rawValue,
                    dimension: ReviewSuggestionCopy.cleanupDimension,
                    oldValue: ReviewSuggestionCopy.cleanupUndecided,
                    newValue: ReviewSuggestionCopy.cleanupKeep
                )
            }.sorted { $0.id < $1.id }
        case .none:
            return []
        }
    }
}

/// Adapter over existing native facts only. Legacy selected/rejected output is
/// never applied as a new user choice; an empty native set is valid.
enum NativeReviewSuggestionAdapter: Sendable {
    static func suggestions(
        scopeID: UUID,
        result: SelectionResult,
        groups: [SimilarGroup]
    ) -> [ReviewSuggestion] {
        let analysisVersion = PhotoAnalysis.currentVersion
        let revision = "native-a\(analysisVersion)-e\(result.engineVersion)"
        var records: [ReviewSuggestion] = []
        for group in groups {
            let winner = group.engineWinner
            guard group.memberIDs.contains(winner) else { continue }
            let proposal = ReviewSuggestionProposal.albumMembership([winner: .included])
            let proposalKey = "album:\(winner.rawValue)=included"
            let kind = "suggestion-\(scopeID.uuidString)-\(revision)-native-\(proposalKey)"
            let id = StableSelectionID.uuid(kind: kind, members: group.memberIDs.sorted {
                $0.rawValue < $1.rawValue
            })
            records.append(ReviewSuggestion(
                id: id,
                scopeID: scopeID,
                candidateIDs: group.memberIDs,
                groupID: group.id,
                analysisVersion: analysisVersion,
                engineVersion: result.engineVersion,
                sourceRevision: revision,
                provenance: .native,
                evidence: .available,
                proposal: proposal
            ))
        }
        return records.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
