import Foundation

extension LibraryAnalysisCoordinator {
    func publishLabels(for item: WorkItem, analysis: PhotoAnalysis) async throws {
        let state: PhotoLabelAnalysisInputState
        switch analysis.content.classificationAvailability {
        case .available:
            state = .available
        case .unavailable:
            state = .unavailable
        case .notRun, nil:
            state = .pending
        }
        let input = PhotoLabelMappingInput(
            assetID: item.asset.id,
            assetRevision: item.asset.modificationFingerprint,
            state: state,
            observations: analysis.content.tags.map {
                PhotoLabelVisionObservation(identifier: $0.name, score: $0.confidence)
            }
        )
        try await catalogStore.publishLabels(
            PhotoLabelMapper().map(input),
            generationID: item.generationID
        )
    }

    static func labelInputState(for failure: LibraryAnalysisFailure) -> PhotoLabelAnalysisInputState {
        switch failure {
        case .unsupported:
            .unsupported
        case .revisionStale:
            .stale
        case .imageLoad, .modelUnavailable, .transientFailure:
            .unavailable
        }
    }

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
