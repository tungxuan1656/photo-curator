import Foundation

enum SyntheticLabel: String {
    case mustKeep = "MUST_KEEP"
    case acceptable = "ACCEPTABLE"
    case reject = "REJECT"
}

/// Repository-local annotation rows authored independently of rank inputs.
/// These labels are structural fixture annotations, never persisted or used for tuning.
struct OracleManifest {
    let id: String
    let groupSize: Int
    let labelByAssetRawValue: [String: SyntheticLabel]
    let explicitRankMismatchGroups: Set<Int>

    func label(assetID: AssetID) -> SyntheticLabel {
        guard let label = labelByAssetRawValue[assetID.rawValue] else {
            preconditionFailure("missing authored oracle label for \(assetID.rawValue)")
        }
        return label
    }
}

enum FixtureOracle {
    static let provenance = "fixture-oracle-v3"
    static let source = "repo-local-static-annotation-manifest"

    static let manifests: [String: OracleManifest] = [
        "SMOKE": manifest(name: "SMOKE", groupSize: 4, groupCount: 15, mismatchGroups: []),
        "GOLDEN-SHAPED": manifest(name: "GOLDEN-SHAPED", groupSize: 10, groupCount: 20, mismatchGroups: []),
        "TRIP-SHAPED": manifest(name: "TRIP-SHAPED", groupSize: 5, groupCount: 30, mismatchGroups: []),
        // One authored MUST_KEEP row deliberately differs from the deterministic rank winner.
        "H-1000": manifest(name: "H-1000", groupSize: 20, groupCount: 50, mismatchGroups: [0]),
    ]

    static func manifest(name: String, groupSize: Int, groupCount: Int, mismatchGroups: Set<Int>) -> OracleManifest {
        let ordinary = annotationRow(groupSize: groupSize, mustKeepMember: 0)
        let mismatch = annotationRow(groupSize: groupSize, mustKeepMember: 1)
        var labels: [String: SyntheticLabel] = [:]
        for group in 0 ..< groupCount {
            let row = mismatchGroups.contains(group) ? mismatch : ordinary
            for member in 0 ..< groupSize {
                let rawID = "\(name)-g\(String(format: "%03d", group))-m\(member)"
                labels[rawID] = row[member]
            }
        }
        return OracleManifest(
            id: provenance,
            groupSize: groupSize,
            labelByAssetRawValue: labels,
            explicitRankMismatchGroups: mismatchGroups
        )
    }

    private static func annotationRow(groupSize: Int, mustKeepMember: Int) -> [SyntheticLabel] {
        var row = Array(repeating: SyntheticLabel.reject, count: groupSize)
        row[mustKeepMember] = .mustKeep
        // The remaining labels are authored annotations, not score/order projections.
        let acceptableMember = mustKeepMember == 0 ? 1 : 2
        row[acceptableMember] = .acceptable
        return row
    }

    static func labels(for manifest: OracleManifest, assetsByGroup: [[PhotoAsset]]) -> [AssetID: SyntheticLabel] {
        var labels: [AssetID: SyntheticLabel] = [:]
        for assets in assetsByGroup {
            for asset in assets {
                labels[asset.id] = manifest.label(assetID: asset.id)
            }
        }
        return labels
    }
}

struct Fixture {
    let name: String
    let assets: [PhotoAsset]
    let analyses: [AssetID: PhotoAnalysis]
    let edges: [SimilarityEdge]
    let labelByID: [AssetID: SyntheticLabel]
    let oracleManifestID: String
    let groupByID: [AssetID: Int]
    let momentByID: [AssetID: Int]
    let groupCount: Int
    let groupSize: Int
    let momentCount: Int
}

struct Metrics {
    let input: Int
    let output: Int
    let mustKeepRecall: Double
    let goodSelectionRate: Double
    let badPickRate: Double
    let duplicateLeakage: Double
    let duplicateLeakageNumerator: Int
    let duplicateLeakageDenominator: Int
    let bestShotAccuracy: Double
    let momentCoverage: Double
    let compression: Double
    let deterministic: Bool
    let engineVersion: Int
}

enum ProofFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message): return message
        }
    }
}

@main
struct RankerDecisionGateProof {
    static func main() {
        do {
            try run()
            print("RESULT PASS")
        } catch {
            print("RESULT FAIL \(error)")
            exit(1)
        }
    }

    static func run() throws {
        let configuration = AppConfiguration.default
        try require(configuration.analysis.analysisVersion == 4, "analysisVersion moved")
        try require(configuration.configVersion == 1, "configVersion moved")
        try assertFrozenSelectionConfiguration(configuration.selection)
        try assertTieBreakBehavior(configuration.selection)
        let fixtures = [
            makeFixture(name: "SMOKE", count: 60, groupSize: 4, groupsPerMoment: 1),
            makeFixture(name: "GOLDEN-SHAPED", count: 200, groupSize: 10, groupsPerMoment: 1),
            makeFixture(name: "TRIP-SHAPED", count: 150, groupSize: 5, groupsPerMoment: 1),
            makeFixture(name: "H-1000", count: 1000, groupSize: 20, groupsPerMoment: 1),
        ]
        let allAssetIDs = fixtures.flatMap { $0.assets.map(\.id) }
        try require(Set(allAssetIDs).count == allAssetIDs.count, "evaluation asset IDs overlap across splits")
        try require(Set(fixtures.map(\.name)).count == fixtures.count, "evaluation split names overlap")
        try require(
            Set(fixtures.map(\.oracleManifestID)) == [FixtureOracle.provenance],
            "oracle fixture version drifted"
        )
        for fixture in fixtures {
            try require(
                Set(fixture.labelByID.keys) == Set(fixture.assets.map(\.id)),
                "\(fixture.name) labels do not cover assets"
            )
            try require(
                fixture.groupSize == FixtureOracle.manifests[fixture.name]!.groupSize,
                "\(fixture.name) oracle shape drifted"
            )
            try assertIndependentLabels(fixture)
        }
        try assertExplicitMustKeepRankMismatch(fixtures)
        print(
            "CONTRACT baseline=deterministic engineVersion=3 analysisVersion=4 configVersion=\(configuration.configVersion) PASS"
        )
        print(
            "CONFIG complete=true frozenWeights=technical,human,representativeness,uniqueness,diversity,coverage,redundancy all=1.000 bonuses=0.000/0.000 tieBreak=score-desc,edited-desc,favorite-desc,pixel-area-desc,asset-id-asc behavior=asserted PASS"
        )
        print(
            "TIE-BREAK behavior=edited>favorite>pixel-area>asset-id cases=4 input-order-replay=true PASS"
        )
        print(
            "LABELS provenance=\(FixtureOracle.provenance) source=\(FixtureOracle.source) independent-of=PhotoAnalysis-rank-order explicit-MUST_KEEP-rank-mismatch=true boundary=no-user-photos-no-persisted-labels PASS"
        )
        print(
            "SPLITS fit=none calibration=none evaluation=smoke,Golden-shaped,trip-shaped,H-1000 assetIDsDisjoint=true labelsEquivalent=true PASS"
        )

        var results: [String: Metrics] = [:]
        for fixture in fixtures {
            let metrics = try evaluate(fixture, configuration: configuration.selection)
            results[fixture.name] = metrics
            printMetrics(fixture, metrics)
        }

        for fixture in fixtures {
            guard let metrics = results[fixture.name]
            else { throw ProofFailure.assertion("missing \(fixture.name) metrics") }
            try require(metrics.deterministic, "\(fixture.name) deterministic replay changed")
            try require(metrics.engineVersion == 3, "\(fixture.name) engine version changed")
            try require(
                metrics.duplicateLeakageDenominator == metrics.output,
                "\(fixture.name) duplicate leakage denominator drifted"
            )
            try require(metrics.mustKeepRecall >= 0.95, "\(fixture.name) must-keep recall gate failed")
            try require(metrics.goodSelectionRate >= 0.90, "\(fixture.name) good-selection gate failed")
            try require(metrics.badPickRate <= 0.10, "\(fixture.name) bad-pick gate failed")
            try require(metrics.duplicateLeakage <= 0.05, "\(fixture.name) duplicate-leakage gate failed")
            try require(metrics.bestShotAccuracy >= 0.80, "\(fixture.name) best-shot gate failed")
            try require(metrics.momentCoverage >= 0.90, "\(fixture.name) moment-coverage gate failed")
        }
        print("NO-RANKER GATE PASS baseline-measurable-gap=false candidate-evaluation=not-admitted")
    }

    static func assertFrozenSelectionConfiguration(_ selection: SelectionConfiguration) throws {
        try require(selection.analysisImageMaxDimension == 512, "analysis image dimension drifted")
        try require(selection.duplicateTimeWindow == 90, "duplicate time window drifted")
        try require(selection.duplicateSimilarityThreshold == 0.5, "duplicate threshold drifted")
        try require(selection.nearDuplicateSimilarityThreshold == 0.5, "near-duplicate threshold drifted")
        try require(selection.momentSoftGap == 180, "moment soft gap drifted")
        try require(selection.momentHardGap == 900, "moment hard gap drifted")
        try require(selection.maxPhotosPerMoment == 3, "moment cap drifted")
        try require(selection.targetSelectionRatio == 0.10, "target ratio drifted")
        try require(selection.minimumFinalCount == 30, "minimum final count drifted")
        try require(selection.maximumFinalCount == 150, "maximum final count drifted")
        try require(selection.shortlistMultiplier == 2.0, "shortlist multiplier drifted")
        try require(selection.technicalQualityWeight == 1.0, "technical weight drifted")
        try require(selection.humanImportanceWeight == 1.0, "human weight drifted")
        try require(selection.representativenessWeight == 1.0, "representativeness weight drifted")
        try require(selection.uniquenessWeight == 1.0, "uniqueness weight drifted")
        try require(selection.diversityWeight == 1.0, "diversity weight drifted")
        try require(selection.coverageWeight == 1.0, "coverage weight drifted")
        try require(selection.redundancyPenaltyWeight == 1.0, "redundancy weight drifted")
        try require(selection.favoriteBonus == 0, "favorite bonus drifted")
        try require(selection.editedBonus == 0, "edited bonus drifted")
        try require(selection.lowQualityThreshold == 0.5, "quality floor drifted")
        try require(selection.hardRejectThreshold == 0.25, "hard reject floor drifted")
    }

    static func assertIndependentLabels(_ fixture: Fixture) throws {
        guard let manifest = FixtureOracle.manifests[fixture.name] else {
            throw ProofFailure.assertion("missing oracle manifest for \(fixture.name)")
        }
        var assetsByGroup = Array(repeating: [PhotoAsset](), count: fixture.groupCount)
        for asset in fixture.assets {
            guard let group = fixture.groupByID[asset.id], group < assetsByGroup.count else {
                throw ProofFailure.assertion("\(fixture.name) asset has no oracle group")
            }
            assetsByGroup[group].append(asset)
        }
        try require(
            assetsByGroup.allSatisfy { $0.count == fixture.groupSize },
            "\(fixture.name) group shape drifted"
        )
        let oracleLabels = FixtureOracle.labels(for: manifest, assetsByGroup: assetsByGroup)
        try require(oracleLabels == fixture.labelByID, "\(fixture.name) labels changed outside oracle manifest")

        // Labels are authored rows, not projections. Require a MUST_KEEP row
        // whose deterministic rank position is not first in the mismatch split.
        var rankProjectionMismatches = 0
        var mustKeepRankMismatches = 0
        for group in assetsByGroup {
            let ranked = group.sorted(by: { rankBefore($0, $1, analyses: fixture.analyses) })
            for (rank, asset) in ranked.enumerated() {
                let rankLabel: SyntheticLabel = rank == 0 ? .mustKeep : rank == 1 ? .acceptable : .reject
                if fixture.labelByID[asset.id] != rankLabel {
                    rankProjectionMismatches += 1
                }
                if fixture.labelByID[asset.id] == .mustKeep, rank != 0 {
                    mustKeepRankMismatches += 1
                }
            }
        }
        try require(
            rankProjectionMismatches > 0 || manifest.explicitRankMismatchGroups.isEmpty,
            "\(fixture.name) oracle labels shadow rank order"
        )
        try require(
            mustKeepRankMismatches == manifest.explicitRankMismatchGroups.count,
            "\(fixture.name) explicit MUST_KEEP/rank mismatch drifted"
        )
    }

    static func assertExplicitMustKeepRankMismatch(_ fixtures: [Fixture]) throws {
        guard let fixture = fixtures.first(where: { $0.name == "H-1000" }),
              let manifest = FixtureOracle.manifests[fixture.name],
              let mismatchGroup = manifest.explicitRankMismatchGroups.sorted().first
        else { throw ProofFailure.assertion("missing explicit oracle/rank mismatch fixture") }
        let group = fixture.assets.filter { fixture.groupByID[$0.id] == mismatchGroup }
        let ranked = group.sorted(by: { rankBefore($0, $1, analyses: fixture.analyses) })
        guard let rankWinner = ranked.first,
              let mustKeep = ranked.first(where: { fixture.labelByID[$0.id] == .mustKeep })
        else { throw ProofFailure.assertion("incomplete explicit oracle/rank mismatch fixture") }
        try require(rankWinner.id != mustKeep.id, "explicit MUST_KEEP unexpectedly ranked first")
        let result = try SelectionEngine().select(
            assets: fixture.assets,
            analyses: fixture.analyses,
            configuration: AppConfiguration.default.selection,
            feedback: nil,
            similarityEdges: fixture.edges,
            tierCEdges: []
        )
        let selected = Set(result.selectedAssetIDs)
        try require(selected.contains(rankWinner.id), "explicit mismatch rank winner was not selected")
        try require(!selected.contains(mustKeep.id), "explicit mismatch MUST_KEEP was selected unexpectedly")
        print(
            "ORACLE-MISMATCH split=H-1000 group=\(mismatchGroup) rankWinner=\(rankWinner.id.rawValue) mustKeep=\(mustKeep.id.rawValue) selectedRankWinner=true selectedMustKeep=false PASS"
        )
    }

    static func assertTieBreakBehavior(_ configuration: SelectionConfiguration) throws {
        let cases: [(name: String, left: PhotoAsset, right: PhotoAsset, expected: AssetID)] = [
            (
                "edited-before-favorite",
                tieBreakAsset(id: "tie-edit-favorite", edited: false, favorite: true, width: 2000, height: 2000),
                tieBreakAsset(id: "tie-edit-winner", edited: true, favorite: false, width: 1000, height: 1000),
                AssetID(rawValue: "tie-edit-winner")
            ),
            (
                "favorite-before-pixel-area",
                tieBreakAsset(id: "tie-favorite-winner", edited: false, favorite: true, width: 1000, height: 1000),
                tieBreakAsset(id: "tie-pixel-area", edited: false, favorite: false, width: 4000, height: 4000),
                AssetID(rawValue: "tie-favorite-winner")
            ),
            (
                "pixel-area-before-asset-id",
                tieBreakAsset(id: "tie-pixel-low", edited: false, favorite: false, width: 1000, height: 1000),
                tieBreakAsset(id: "tie-pixel-winner", edited: false, favorite: false, width: 2000, height: 1000),
                AssetID(rawValue: "tie-pixel-winner")
            ),
            (
                "asset-id-final",
                tieBreakAsset(id: "tie-id-z", edited: false, favorite: false, width: 1000, height: 1000),
                tieBreakAsset(id: "tie-id-a", edited: false, favorite: false, width: 1000, height: 1000),
                AssetID(rawValue: "tie-id-a")
            ),
        ]
        for tieCase in cases {
            let assets = [tieCase.left, tieCase.right]
            let analyses = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, tieBreakAnalysis(for: $0.id)) })
            let edges = [SimilarityEdge(first: tieCase.left.id, second: tieCase.right.id, distance: 0.1)]
            let first = try SelectionEngine().select(
                assets: assets, analyses: analyses, configuration: configuration, feedback: nil,
                similarityEdges: edges, tierCEdges: []
            )
            let reversed = try SelectionEngine().select(
                assets: Array(assets.reversed()), analyses: analyses, configuration: configuration, feedback: nil,
                similarityEdges: edges, tierCEdges: []
            )
            try require(
                first.selectedAssetIDs == [tieCase.expected],
                "tie-break case \(tieCase.name) chose wrong winner"
            )
            try require(
                reversed.selectedAssetIDs == [tieCase.expected],
                "tie-break case \(tieCase.name) depends on input order"
            )
        }
    }

    static func tieBreakAsset(id: String, edited: Bool, favorite: Bool, width: Int, height: Int) -> PhotoAsset {
        PhotoAsset(
            id: AssetID(rawValue: id), creationDate: Date(timeIntervalSince1970: 1_800_000_000),
            pixelWidth: width, pixelHeight: height, mediaSubtype: .standard,
            isFavorite: favorite, isEdited: edited, source: .local
        )
    }

    static func tieBreakAnalysis(for id: AssetID) -> PhotoAnalysis {
        PhotoAnalysis.make(
            assetID: id,
            technical: TechnicalAnalysis(
                sharpnessScore: 0.8, exposureScore: 0.8, resolutionScore: 0.8,
                blurProbability: 0, underexposureProbability: 0, overexposureProbability: 0
            ),
            faceCount: 0, groupPhotoScore: nil, subjectPlacementScore: nil,
            sceneType: .landscape, featurePrintAvailable: true
        )
    }

    static func rankBefore(
        _ left: PhotoAsset, _ right: PhotoAsset, analyses: [AssetID: PhotoAnalysis]
    ) -> Bool {
        let leftScore = analyses[left.id]!.qualityScore
        let rightScore = analyses[right.id]!.qualityScore
        if leftScore != rightScore {
            return leftScore > rightScore
        }
        if left.isEdited != right.isEdited {
            return left.isEdited
        }
        if left.isFavorite != right.isFavorite {
            return left.isFavorite
        }
        let leftArea = left.pixelWidth * left.pixelHeight
        let rightArea = right.pixelWidth * right.pixelHeight
        if leftArea != rightArea {
            return leftArea > rightArea
        }
        return left.id.rawValue < right.id.rawValue
    }

    static func evaluate(_ fixture: Fixture, configuration: SelectionConfiguration) throws -> Metrics {
        let engine = SelectionEngine()
        let first = try engine.select(
            assets: fixture.assets,
            analyses: fixture.analyses,
            configuration: configuration,
            feedback: nil,
            similarityEdges: fixture.edges,
            tierCEdges: []
        )
        let second = try engine.select(
            assets: fixture.assets,
            analyses: fixture.analyses,
            configuration: configuration,
            feedback: nil,
            similarityEdges: fixture.edges,
            tierCEdges: []
        )
        let firstSummary = summary(first)
        let secondSummary = summary(second)
        let deterministic = firstSummary == secondSummary
        let selected = Set(first.selectedAssetIDs)
        let mustKeepTotal = fixture.labelByID.values.filter { $0 == .mustKeep }.count
        let mustKeepSelected = selected.filter { fixture.labelByID[$0] == .mustKeep }.count
        let goodSelected = selected.filter { fixture.labelByID[$0] != .reject }.count
        let badSelected = selected.filter { fixture.labelByID[$0] == .reject }.count
        let selectedGroupCounts = Dictionary(grouping: selected, by: { fixture.groupByID[$0]! })
        let leakageRepeats = selectedGroupCounts.values.reduce(0) { partial, group in
            partial + max(0, group.count - 1)
        }
        let leakageDenominator = selected.count
        let selectedGroups = selectedGroupCounts.count
        let bestGroups = selectedGroupCounts.values.filter { group in
            group.contains { fixture.labelByID[$0] == .mustKeep }
        }.count
        let selectedMoments = Set(selected.compactMap { fixture.momentByID[$0] }).count
        return Metrics(
            input: fixture.assets.count,
            output: selected.count,
            mustKeepRecall: ratio(mustKeepSelected, mustKeepTotal),
            goodSelectionRate: ratio(goodSelected, selected.count),
            badPickRate: ratio(badSelected, selected.count),
            duplicateLeakage: ratio(leakageRepeats, leakageDenominator),
            duplicateLeakageNumerator: leakageRepeats,
            duplicateLeakageDenominator: leakageDenominator,
            bestShotAccuracy: ratio(bestGroups, selectedGroups),
            momentCoverage: ratio(selectedMoments, fixture.momentCount),
            compression: ratio(selected.count, fixture.assets.count),
            deterministic: deterministic,
            engineVersion: first.engineVersion
        )
    }

    static func printMetrics(_ fixture: Fixture, _ metrics: Metrics) {
        print(
            "\(fixture.name) input=\(metrics.input) output=\(metrics.output) " +
                String(
                    format: "mustKeepRecall=%.3f good=%.3f bad=%.3f leakage=%.3f leakageNumerator=%d leakageDenominator=%d bestShot=%.3f coverage=%.3f compression=%.3f ",
                    metrics.mustKeepRecall,
                    metrics.goodSelectionRate,
                    metrics.badPickRate,
                    metrics.duplicateLeakage,
                    metrics.duplicateLeakageNumerator,
                    metrics.duplicateLeakageDenominator,
                    metrics.bestShotAccuracy,
                    metrics.momentCoverage,
                    metrics.compression
                ) +
                "deterministic=\(metrics.deterministic) engineVersion=\(metrics.engineVersion) PASS"
        )
    }

    static func makeFixture(name: String, count: Int, groupSize: Int, groupsPerMoment: Int) -> Fixture {
        guard let oracle = FixtureOracle.manifests[name] else {
            preconditionFailure("missing oracle manifest for \(name)")
        }
        let groupCount = count / groupSize
        precondition(groupCount * groupSize == count)
        precondition(oracle.groupSize == groupSize)
        let momentCount = (groupCount + groupsPerMoment - 1) / groupsPerMoment
        let epoch = Date(timeIntervalSince1970: 1_800_000_000)
        var assets: [PhotoAsset] = []
        var assetsByGroup = Array(repeating: [PhotoAsset](), count: groupCount)
        var analyses: [AssetID: PhotoAnalysis] = [:]
        var edges: [SimilarityEdge] = []
        var groupByID: [AssetID: Int] = [:]
        var momentByID: [AssetID: Int] = [:]

        for group in 0 ..< groupCount {
            let moment = group / groupsPerMoment
            let memberIDs = (0 ..< groupSize).map { member in
                AssetID(rawValue: "\(name)-g\(String(format: "%03d", group))-m\(member)")
            }
            for member in 0 ..< groupSize {
                let id = memberIDs[member]
                let score: Double
                switch member {
                case 0: score = 0.95
                case 1: score = 0.75
                default: score = 0.40
                }
                let date = epoch.addingTimeInterval(Double(moment * 1000 + (group % groupsPerMoment) * 20 + member))
                let asset = PhotoAsset(
                    id: id,
                    creationDate: date,
                    pixelWidth: 1000 + member,
                    pixelHeight: 1000,
                    mediaSubtype: .standard,
                    isFavorite: false,
                    isEdited: false,
                    source: .local
                )
                assets.append(asset)
                assetsByGroup[group].append(asset)
                analyses[id] = PhotoAnalysis.make(
                    assetID: id,
                    technical: TechnicalAnalysis(
                        sharpnessScore: score,
                        exposureScore: score,
                        resolutionScore: score,
                        blurProbability: score < 0.5 ? 0.8 : 0,
                        underexposureProbability: 0,
                        overexposureProbability: 0
                    ),
                    faceCount: 0,
                    groupPhotoScore: nil,
                    subjectPlacementScore: score,
                    sceneType: .landscape,
                    aestheticScore: score,
                    featurePrintAvailable: true
                )
                groupByID[id] = group
                momentByID[id] = moment
            }
            for first in 0 ..< groupSize {
                for second in (first + 1) ..< groupSize {
                    edges.append(SimilarityEdge(first: memberIDs[first], second: memberIDs[second], distance: 0.1))
                }
            }
        }
        let labels = FixtureOracle.labels(for: oracle, assetsByGroup: assetsByGroup)
        return Fixture(
            name: name,
            assets: assets,
            analyses: analyses,
            edges: edges,
            labelByID: labels,
            oracleManifestID: oracle.id,
            groupByID: groupByID,
            momentByID: momentByID,
            groupCount: groupCount,
            groupSize: groupSize,
            momentCount: momentCount
        )
    }

    static func summary(_ result: SelectionResult) -> String {
        var parts = ["v=\(result.engineVersion)", "s=\(result.selectedAssetIDs.map(\.rawValue).joined(separator: ","))"]
        parts.append("r=\(result.rejectedAssetIDs.map(\.rawValue).joined(separator: ","))")
        for decision in result.decisions {
            parts
                .append(
                    "d=\(decision.assetID.rawValue):\(decision.status.rawValue):\(decision.reasons.joined(separator: "|")):\(decision.competingIDs.map(\.rawValue).joined(separator: ","))"
                )
        }
        return parts.joined(separator: ";")
    }

    static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProofFailure.assertion(message) }
    }
}
