import Foundation

extension LibraryAnalysisCoordinator {
    func placeholderReference(for item: WorkItem) -> AnalysisEvidenceReference {
        AnalysisEvidenceReference(
            identifier: "in-flight",
            assetID: item.asset.id,
            capability: capability,
            assetFingerprint: item.asset.modificationFingerprint,
            revision: item.revision
        )
    }

    static func failure(for error: SelectionError) -> LibraryAnalysisFailure {
        switch error {
        case .invalidInput: .unsupported
        case .internal, .memoryCritical: .transientFailure
        case .cancelled: .transientFailure
        }
    }

    static func failure(for error: LibraryAnalysisEvidenceStoreError) -> LibraryAnalysisFailure {
        switch error {
        case .unsupportedCapability, .assetMismatch, .invalidReference: .unsupported
        case .missingAssetFingerprint, .revisionMismatch: .revisionStale
        }
    }

    static func catalogReason(for failure: LibraryAnalysisFailure) -> AnalysisWorkReason {
        switch failure {
        case let .imageLoad(error):
            switch error {
            case .accessRequired: .accessRequired
            case .iCloudWaiting: .iCloudWaiting
            case .assetMissing: .unsupported
            case .transientFailure, .cancelled: .transientFailure
            }
        case .modelUnavailable: .modelUnavailable
        case .revisionStale: .revisionStale
        case .unsupported: .unsupported
        case .transientFailure: .transientFailure
        }
    }

    static func retryPolicy(for failure: LibraryAnalysisFailure) -> LibraryAnalysisRetryPolicy {
        switch failure {
        case let .imageLoad(error):
            switch error {
            case .accessRequired: .accessRequired
            case .iCloudWaiting: .waitForAsset
            case .assetMissing: .doNotRetry
            case .transientFailure, .cancelled: .retryExplicitly
            }
        case .modelUnavailable, .transientFailure: .retryExplicitly
        case .revisionStale: .retryAfterRevisionChange
        case .unsupported: .doNotRetry
        }
    }

    func isCurrentRun(_ token: UInt64) -> Bool {
        token == runToken
    }
}
