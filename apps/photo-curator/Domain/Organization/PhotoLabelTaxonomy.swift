import Foundation

/// The user-facing facet for an admitted catalog label. These facets are
/// intentionally narrower than Vision's raw classification vocabulary.
nonisolated enum PhotoLabelFacet: String, Codable, CaseIterable, Hashable, Sendable {
    case imageKind
    case content
    case setting
    case personal
}

/// Stable IDs are the only label identifiers that may cross the provider
/// boundary. A raw Vision identifier is evidence, not a catalog label ID.
nonisolated enum PhotoLabelID: String, Codable, CaseIterable, Hashable, Sendable {
    case people = "com.tungxuan.photo-curator.label.people"
    case group = "com.tungxuan.photo-curator.label.group"
    case landscape = "com.tungxuan.photo-curator.label.landscape"
    case architecture = "com.tungxuan.photo-curator.label.architecture"
    case food = "com.tungxuan.photo-curator.label.food"
    case animal = "com.tungxuan.photo-curator.label.animal"
    case indoor = "com.tungxuan.photo-curator.label.indoor"
    case outdoor = "com.tungxuan.photo-curator.label.outdoor"
    case document = "com.tungxuan.photo-curator.label.document"
    case screenshot = "com.tungxuan.photo-curator.label.screenshot"
}

nonisolated enum PhotoLabelEvidenceSource: String, Codable, Hashable, Sendable {
    case visionClassification
}

/// A frozen definition consumed by the mapper and, later, by the persistence
/// and query lanes. Localization keys are stable identities; localized copy
/// belongs to the UI/catalog layer.
nonisolated struct PhotoLabelDefinition: Codable, Hashable, Sendable {
    let id: PhotoLabelID
    let visionIdentifier: String
    let facet: PhotoLabelFacet
    let localizationKey: String
    let source: PhotoLabelEvidenceSource
    let exclusions: Set<PhotoLabelID>
    let compatibleLabels: Set<PhotoLabelID>
}

/// The exact native taxonomy admitted by feat-044.
nonisolated enum PhotoLabelTaxonomy {
    static let durableLayerRevision = "catalog-labels-v7"
    static let revision = "vision-scene-taxonomy-v1"
    static let sourceRevision = "vision-classification-observation-v1"
    /// VNClassifyImageRequest is intentionally not assigned an SDK revision;
    /// Apple exposes the selected default through the running OS. Persist the
    /// provenance as unpinned rather than claiming a revision we did not set.
    static let providerRevision = "vision-classify-sdk-default-unpinned"
    static let runtimeRevision = "vision-ios26-native-v1"
    static let mappingRevision = "vision-scene-map-v2"
    static let confidenceFloor = 0.75
    static let ambiguityMargin = 0.10

    static let supportedLabels: [PhotoLabelDefinition] = {
        let all = Set(PhotoLabelID.allCases)
        let noExclusions: Set<PhotoLabelID> = []
        let imageKindExclusions: Set<PhotoLabelID> = [.document, .screenshot]
        let settingExclusions: Set<PhotoLabelID> = [.indoor, .outdoor]

        return [
            definition(.people, visionIdentifier: "people", facet: .content, exclusions: noExclusions, all: all),
            definition(.group, visionIdentifier: "group", facet: .content, exclusions: noExclusions, all: all),
            definition(.landscape, visionIdentifier: "landscape", facet: .content, exclusions: noExclusions, all: all),
            definition(
                .architecture,
                visionIdentifier: "architecture",
                facet: .content,
                exclusions: noExclusions,
                all: all
            ),
            definition(.food, visionIdentifier: "food", facet: .content, exclusions: noExclusions, all: all),
            definition(.animal, visionIdentifier: "animal", facet: .content, exclusions: noExclusions, all: all),
            definition(.indoor, visionIdentifier: "indoor", facet: .setting, exclusions: settingExclusions, all: all),
            definition(.outdoor, visionIdentifier: "outdoor", facet: .setting, exclusions: settingExclusions, all: all),
            definition(.document, visionIdentifier: "document", facet: .imageKind, exclusions: imageKindExclusions,
                       all: all),
            definition(.screenshot, visionIdentifier: "screenshot", facet: .imageKind, exclusions: imageKindExclusions,
                       all: all), // swiftlint:disable:this trailing_comma
        ]
    }()

    static func definition(for labelID: PhotoLabelID) -> PhotoLabelDefinition {
        supportedLabels.first { $0.id == labelID }!
    }

    static func labelID(forRawIdentifier identifier: String) -> PhotoLabelID? {
        switch identifier {
        case "people": .people
        case "group": .group
        case "landscape": .landscape
        case "architecture": .architecture
        case "food": .food
        case "animal": .animal
        case "indoor": .indoor
        case "outdoor": .outdoor
        case "document": .document
        case "screenshot": .screenshot
        default: nil
        }
    }

    static func areCompatible(_ first: PhotoLabelID, _ second: PhotoLabelID) -> Bool {
        first == second || definition(for: first).compatibleLabels.contains(second)
    }

    private static func definition(
        _ id: PhotoLabelID,
        visionIdentifier: String,
        facet: PhotoLabelFacet,
        exclusions: Set<PhotoLabelID>,
        all: Set<PhotoLabelID>
    ) -> PhotoLabelDefinition {
        PhotoLabelDefinition(
            id: id,
            visionIdentifier: visionIdentifier,
            facet: facet,
            localizationKey: "label.\(id.rawValue)",
            source: .visionClassification,
            exclusions: exclusions.subtracting([id]),
            compatibleLabels: all.subtracting(exclusions)
        )
    }
}
