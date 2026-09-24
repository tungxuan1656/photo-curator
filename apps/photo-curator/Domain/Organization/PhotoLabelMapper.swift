import Foundation

/// A raw observation from `VNClassifyImageRequest`. The score is retained as
/// provider evidence; it is not presented as a calibrated probability.
nonisolated struct PhotoLabelVisionObservation: Codable, Hashable, Sendable {
    let identifier: String
    let score: Double
}

/// State supplied by the analysis lifecycle before mapping. `.available` is
/// the only state that may produce automatic assignments.
nonisolated enum PhotoLabelAnalysisInputState: String, Codable, Hashable, Sendable {
    case pending
    case unsupported
    case unavailable
    case stale
    case available
}

/// Explicit result states prevent an empty successful classification from
/// being confused with a failed, stale, pending, or unsupported analysis.
nonisolated enum PhotoLabelAnalysisOutcome: String, Codable, Hashable, Sendable {
    case pending
    case unsupported
    case unavailable
    case stale
    case completedEmpty
    case completed

    var isSuccessful: Bool {
        self == .completed || self == .completedEmpty
    }
}

/// Immutable automatic evidence for one asset/label pair. Corrections and
/// personal assignments are deliberately not represented by this type.
nonisolated struct PhotoLabelAutomaticAssignment: Codable, Hashable, Sendable {
    let assetID: AssetID
    let assetRevision: AssetModificationFingerprint
    let labelID: PhotoLabelID
    let facet: PhotoLabelFacet
    let sourceRevision: String
    let providerRevision: String
    let runtimeRevision: String
    let mappingRevision: String
    let taxonomyRevision: String
    let evidenceSource: PhotoLabelEvidenceSource
    let outcome: PhotoLabelAnalysisOutcome
    let rawScore: Double?
    let evidenceReferenceID: String?
    let generationID: UUID?
    let analysisRevision: Int?
    let confidenceFloor: Double
    let ambiguityMargin: Double
}

/// Pure mapper input. The catalog/pipeline lane owns when this snapshot is
/// created and how it is persisted.
nonisolated struct PhotoLabelMappingInput: Sendable {
    let assetID: AssetID
    let assetRevision: AssetModificationFingerprint
    let state: PhotoLabelAnalysisInputState
    let observations: [PhotoLabelVisionObservation]
    let evidenceReferenceID: String?
    let generationID: UUID?
    let analysisRevision: Int?

    init(
        assetID: AssetID,
        assetRevision: AssetModificationFingerprint,
        state: PhotoLabelAnalysisInputState = .available,
        observations: [PhotoLabelVisionObservation] = [],
        evidenceReferenceID: String? = nil,
        generationID: UUID? = nil,
        analysisRevision: Int? = nil
    ) {
        self.assetID = assetID
        self.assetRevision = assetRevision
        self.state = state
        self.observations = observations
        self.evidenceReferenceID = evidenceReferenceID
        self.generationID = generationID
        self.analysisRevision = analysisRevision
    }
}

/// Mapping output, including raw identifiers that this frozen taxonomy does
/// not admit. Unsupported observations do not become guessed stable labels.
nonisolated struct PhotoLabelMappingResult: Sendable {
    let assetID: AssetID
    let assetRevision: AssetModificationFingerprint
    let outcome: PhotoLabelAnalysisOutcome
    let assignments: [PhotoLabelAutomaticAssignment]
    let unsupportedIdentifiers: [String]
    let evidenceReferenceID: String?
    let generationID: UUID?
    let analysisRevision: Int?
    let confidenceFloor: Double
    let ambiguityMargin: Double

    func committed(with evidence: AnalysisEvidenceReference, generationID: UUID) -> Self {
        let assignments = assignments.map { assignment in
            PhotoLabelAutomaticAssignment(
                assetID: assignment.assetID,
                assetRevision: assignment.assetRevision,
                labelID: assignment.labelID,
                facet: assignment.facet,
                sourceRevision: assignment.sourceRevision,
                providerRevision: assignment.providerRevision,
                runtimeRevision: assignment.runtimeRevision,
                mappingRevision: assignment.mappingRevision,
                taxonomyRevision: assignment.taxonomyRevision,
                evidenceSource: assignment.evidenceSource,
                outcome: assignment.outcome,
                rawScore: assignment.rawScore,
                evidenceReferenceID: evidence.identifier,
                generationID: generationID,
                analysisRevision: assignment.analysisRevision,
                confidenceFloor: assignment.confidenceFloor,
                ambiguityMargin: assignment.ambiguityMargin
            )
        }
        return PhotoLabelMappingResult(
            assetID: assetID,
            assetRevision: assetRevision,
            outcome: outcome,
            assignments: assignments,
            unsupportedIdentifiers: unsupportedIdentifiers,
            evidenceReferenceID: evidence.identifier,
            generationID: generationID,
            analysisRevision: analysisRevision,
            confidenceFloor: confidenceFloor,
            ambiguityMargin: ambiguityMargin
        )
    }
}

nonisolated struct PhotoLabelMapper: Sendable {
    let confidenceFloor: Double
    let ambiguityMargin: Double

    init(
        confidenceFloor: Double = PhotoLabelTaxonomy.confidenceFloor,
        ambiguityMargin: Double = PhotoLabelTaxonomy.ambiguityMargin
    ) {
        self.confidenceFloor = confidenceFloor
        self.ambiguityMargin = ambiguityMargin
    }

    // swiftlint:disable:next function_body_length
    func map(_ input: PhotoLabelMappingInput) -> PhotoLabelMappingResult {
        let passthroughOutcome = outcome(for: input.state)
        guard input.state == .available else {
            return PhotoLabelMappingResult(
                assetID: input.assetID,
                assetRevision: input.assetRevision,
                outcome: passthroughOutcome,
                assignments: [],
                unsupportedIdentifiers: [],
                evidenceReferenceID: input.evidenceReferenceID,
                generationID: input.generationID,
                analysisRevision: input.analysisRevision,
                confidenceFloor: confidenceFloor,
                ambiguityMargin: ambiguityMargin
            )
        }

        var bestByLabel: [PhotoLabelID: PhotoLabelVisionObservation] = [:]
        var unsupported = Set<String>()
        for observation in input.observations {
            guard let labelID = PhotoLabelTaxonomy.labelID(forRawIdentifier: observation.identifier) else {
                unsupported.insert(observation.identifier)
                continue
            }
            guard observation.score.isFinite, (0 ... 1).contains(observation.score) else { continue }
            if let current = bestByLabel[labelID], current.score >= observation.score {
                continue
            }
            bestByLabel[labelID] = observation
        }

        let accepted = bestByLabel.compactMap { labelID, observation -> (PhotoLabelID, PhotoLabelVisionObservation)? in
            guard observation.score >= confidenceFloor else { return nil }
            guard isAdmitted(labelID, score: observation.score, comparedWith: bestByLabel) else { return nil }
            return (labelID, observation)
        }
        .sorted { order(of: $0.0) < order(of: $1.0) }

        let assignments = accepted.map { labelID, observation in
            let definition = PhotoLabelTaxonomy.definition(for: labelID)
            return PhotoLabelAutomaticAssignment(
                assetID: input.assetID,
                assetRevision: input.assetRevision,
                labelID: labelID,
                facet: definition.facet,
                sourceRevision: PhotoLabelTaxonomy.sourceRevision,
                providerRevision: PhotoLabelTaxonomy.providerRevision,
                runtimeRevision: PhotoLabelTaxonomy.runtimeRevision,
                mappingRevision: PhotoLabelTaxonomy.mappingRevision,
                taxonomyRevision: PhotoLabelTaxonomy.revision,
                evidenceSource: definition.source,
                outcome: .completed,
                rawScore: observation.score,
                evidenceReferenceID: input.evidenceReferenceID,
                generationID: input.generationID,
                analysisRevision: input.analysisRevision,
                confidenceFloor: confidenceFloor,
                ambiguityMargin: ambiguityMargin
            )
        }

        return PhotoLabelMappingResult(
            assetID: input.assetID,
            assetRevision: input.assetRevision,
            outcome: assignments.isEmpty ? .completedEmpty : .completed,
            assignments: assignments,
            unsupportedIdentifiers: unsupported.sorted(),
            evidenceReferenceID: input.evidenceReferenceID,
            generationID: input.generationID,
            analysisRevision: input.analysisRevision,
            confidenceFloor: confidenceFloor,
            ambiguityMargin: ambiguityMargin
        )
    }

    private func isAdmitted(
        _ labelID: PhotoLabelID,
        score: Double,
        comparedWith candidates: [PhotoLabelID: PhotoLabelVisionObservation]
    ) -> Bool {
        let definition = PhotoLabelTaxonomy.definition(for: labelID)
        for (otherID, otherObservation) in candidates where otherID != labelID {
            guard definition.exclusions.contains(otherID) else { continue }
            let lead = score - otherObservation.score
            if lead < ambiguityMargin {
                return false
            }
        }
        return true
    }

    private func outcome(for state: PhotoLabelAnalysisInputState) -> PhotoLabelAnalysisOutcome {
        switch state {
        case .pending: .pending
        case .unsupported: .unsupported
        case .unavailable: .unavailable
        case .stale: .stale
        case .available: .completedEmpty
        }
    }

    private func order(of labelID: PhotoLabelID) -> Int {
        PhotoLabelTaxonomy.supportedLabels.firstIndex { $0.id == labelID } ?? Int.max
    }
}
