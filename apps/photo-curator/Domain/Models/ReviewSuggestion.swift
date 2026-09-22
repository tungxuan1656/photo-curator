import Foundation
import SwiftUI

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
    static let advisoryNote = LocalizedStringResource("The app suggested this. You decide.")
    static let useSuggestion = LocalizedStringResource("Use Suggestion")
    static let keepMyChoice = LocalizedStringResource("Keep My Choice")
    static let previewTitle = LocalizedStringResource("Review Suggested Changes")
    static let applyTitle = LocalizedStringResource("Apply These Changes")
    static let changedNotice = LocalizedStringResource("This suggestion changed. Review it again.")
    static let evidenceAvailable = LocalizedStringResource("Suggestion available")
    static let evidenceInsufficient = LocalizedStringResource("Not enough information for a suggestion")
    static let evidenceUnavailable = LocalizedStringResource("Analysis unavailable")
    static let albumDimension = LocalizedStringResource("Album membership")
    static let cleanupDimension = LocalizedStringResource("Cleanup choice")
    static let albumUnset = LocalizedStringResource("Not chosen for album")
    static let albumIncluded = LocalizedStringResource("In album")
    static let albumExcluded = LocalizedStringResource("Excluded from album")
    static let cleanupUndecided = LocalizedStringResource("Undecided")
    static let cleanupKeep = LocalizedStringResource("Keep")
    static let cleanupStaged = LocalizedStringResource("Staged for deletion")
}

struct ReviewSuggestionPreviewRow: Sendable, Identifiable {
    let id: String
    let dimension: LocalizedStringResource
    let oldValue: LocalizedStringResource
    let newValue: LocalizedStringResource
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

    /// Exact IDs plus one dimension and its per-asset values against the
    /// live model state, using owner copy keys so both languages resolve
    /// from the catalog. The caller supplies the current choice per ID and
    /// rows whose proposal already matches live state are dropped, so
    /// no-op proposals never render as phantom changes.
    func previewRows(currentAlbum: (AssetID) -> AlbumMembership) -> [ReviewSuggestionPreviewRow] {
        switch proposal {
        case let .albumMembership(values):
            return values.compactMap { assetID, membership in
                guard currentAlbum(assetID) != membership else { return nil }
                let newValue: LocalizedStringResource = switch membership {
                case .unset: ReviewSuggestionCopy.albumUnset
                case .included: ReviewSuggestionCopy.albumIncluded
                case .excluded: ReviewSuggestionCopy.albumExcluded
                }
                let current = currentAlbum(assetID)
                let oldValue: LocalizedStringResource = switch current {
                case .unset: ReviewSuggestionCopy.albumUnset
                case .included: ReviewSuggestionCopy.albumIncluded
                case .excluded: ReviewSuggestionCopy.albumExcluded
                }
                return ReviewSuggestionPreviewRow(
                    id: assetID.rawValue,
                    dimension: ReviewSuggestionCopy.albumDimension,
                    oldValue: oldValue,
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
    /// Live staleness input: the engine fact set behind the current
    /// proposals. The model recomputes the revision from these same facts
    /// at preview time; any drift (regroup, re-analysis) marks the preview
    /// stale so the user previews the new proposal instead.
    struct Facts: Sendable {
        let analysisVersion: Int
        let engineVersion: Int
        let winnerByGroup: [ClusterID: AssetID]
    }

    static func facts(result: SelectionResult, groups: [SimilarGroup]) -> Facts {
        var winnerByGroup: [ClusterID: AssetID] = [:]
        for group in groups {
            winnerByGroup[group.id] = group.engineWinner
        }
        return Facts(
            analysisVersion: PhotoAnalysis.currentVersion,
            engineVersion: result.engineVersion,
            winnerByGroup: winnerByGroup
        )
    }

    static func revision(result: SelectionResult, scopeID _: UUID) -> String {
        "native-a\(PhotoAnalysis.currentVersion)-e\(result.engineVersion)"
    }

    static func revision(facts: Facts) -> String {
        let winners = facts.winnerByGroup.sorted { $0.key.rawValue.uuidString < $1.key.rawValue.uuidString }
            .map { "\($0.key.rawValue.uuidString)=\($0.value.rawValue)" }
            .joined(separator: ",")
        return "native-a\(facts.analysisVersion)-e\(facts.engineVersion)-w\(winners)"
    }

    static func suggestions(
        scopeID: UUID,
        result: SelectionResult,
        groups: [SimilarGroup]
    ) -> [ReviewSuggestion] {
        let facts = facts(result: result, groups: groups)
        let revision = revision(facts: facts)
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
                analysisVersion: facts.analysisVersion,
                engineVersion: facts.engineVersion,
                sourceRevision: revision,
                provenance: .native,
                evidence: .available,
                proposal: proposal
            ))
        }
        return records.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
