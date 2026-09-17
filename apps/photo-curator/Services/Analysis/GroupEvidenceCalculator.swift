import Foundation

/// Group evidence calculator (mini-020a, feat-020).
///
/// Pure map with no pipeline wiring: the caller passes the Tier-A face
/// observation count (`VNDetectFaceRectanglesRequest` results count) plus the
/// transient per-face `faceCaptureQuality` values
/// (`VNDetectFaceCaptureQualityRequest` results, as `Double`) from the same
/// `performAll` pass, and this maps them to the frozen distribution triple
/// (`faceCount`, `minFaceQuality`, `meanFaceQuality`) per
/// features/feat-020.md (frozen 2026-09-17).
///
/// Unavailable values are explicit: no faces maps to all-nil, and missing or
/// empty quality values map to count-only — never a fabricated default. No
/// box, landmark, crop, embedding, or pixel buffer crosses to the caller:
/// the inputs are scalars only and the output is bounded scalars only
/// (`faceCount = max(0, count)`; qualities clamped to 0…1). Same inputs
/// always give the same outputs: no Vision call, no I/O. Transient only:
/// nothing here is persisted; the parent wires persistence at Task 3.
enum GroupEvidenceCalculator {
    /// Output: the frozen per-face distribution triple. All Optional so the
    /// frozen unavailable arms stay explicit: all-nil when no faces were
    /// observed, count-only when quality values are unavailable.
    struct MappedFacts: Sendable {
        /// Bounded face count (`max(0, count)`); nil when no faces observed.
        let faceCount: Int?
        /// Minimum per-face quality clamped to 0…1; nil when no faces or
        /// quality unavailable.
        let minFaceQuality: Double?
        /// Mean per-face quality clamped to 0…1; nil when no faces or quality
        /// unavailable.
        let meanFaceQuality: Double?
    }

    /// Pure map from the Tier-A face count plus per-face quality values to
    /// the frozen distribution triple.
    ///
    /// `faceCount` is the Tier-A observation count (zero or negative degrades
    /// to the no-faces arm); `faceQualities` is nil when the quality request
    /// threw or never ran. An empty array degrades to the quality-missing
    /// arm, the same as nil: the caller keeps count-only. Qualities are
    /// clamped to 0…1 before the min/mean fold, so both outputs are bounded
    /// by construction. Same inputs always give the same outputs.
    /// Nonisolated: builds scalars only, so the off-main lane calls it
    /// without hopping back to the MainActor.
    nonisolated static func map(faceCount: Int, faceQualities: [Double]?) -> MappedFacts {
        guard faceCount > 0 else {
            return MappedFacts(faceCount: nil, minFaceQuality: nil, meanFaceQuality: nil)
        }
        let boundedCount = max(0, faceCount)
        guard let qualities = faceQualities, !qualities.isEmpty else {
            return MappedFacts(faceCount: boundedCount, minFaceQuality: nil, meanFaceQuality: nil)
        }
        // Local clamp (not the `PhotoAnalysis` shared rule) so this
        // nonisolated map touches no static — and no main-actor-isolated —
        // state; same 0…1 bound either way.
        let clamped = qualities.map { min(1.0, max(0.0, $0)) }
        let total = clamped.reduce(0.0, +)
        return MappedFacts(
            faceCount: boundedCount,
            minFaceQuality: clamped.min(),
            meanFaceQuality: total / Double(clamped.count)
        )
    }
}
