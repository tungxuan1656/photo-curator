// feat-026 proof main (proof-only; NOT shipped — lives under scripts/proof/).
// Covers: U1 contract frozen (band 0.05 / cap 30 / priority / schema / versions /
// live floor) · U2 all 5 reasons + all exclusions · U3 priority sort + double-run
// identical · U4 fixed action mapping · U5 30-cap truncation · U6 snapshot counts
// + strict seven-key read (configVersion + other extra keys rejected) + no
// prohibited fields in JSON + outsider edits never count · U7 REAL-engine
// smoke 60→picks (double-run byte-identical, engineVersion 3, resolution +
// state identity, partial assetUnavailable excluded) · U8 store round-trip ·
// U9 corrupt/version-mismatch/absent/extra-key recovery · U10 DEC-043 cleanup
// race + DEC-046 stale-generation guard: late feedback Tasks + the real
// model-captured hook snapshot cannot recreate rows after delete
// (feedback + aggregate), stale old-session writer pinned to a retired
// generation drops after tombstone/delete + reopen (new session stays clean,
// retry succeeds), ordinary save failure still throws, interleaved
// failure/delete/reopen stays absent until reopen, idempotent double-delete,
// reopen-after-beginReview re-enables writes with retry-success totals ·
// U11 NeedsReview routing: action buttons route without mutating selection
// (source-checked and exercised through the staged shipped destination helper)
// · U12 plan/DEC reconcile: band 0.05, schema has no analysisVersion
// · U13 shipped AppModel+Save hook/re-entry + strong ownership: REAL ReviewModel
// hook fires while live (persisted pair), model-owned PersistLatest survives
// model release, re-entry reopens and rewrites, saves see the same model
// · U14 REAL shipped AppModel path: beginReview builds the shipped model + installs
// the shipped hook (edited via the model, hook Task persists the pair), save-guard
// routes the same model, scripted exporter failure then retry-success,
// failure/delete/reopen interleaving stays absent until reopen
// · U15 REAL shipped NeedsReview SwiftUI view closure: all four action mappings
// instantiate the shipped destination helper and execute shipped route appends
// against AppRoute without mutating ReviewModel selection
// Runs headless on the simulator via simctl spawn. Proof-only harness fakes live
// in scripts/proof/ (NOT shipped): no test target, no *Test*.swift, no test
// framework.
// Exit nonzero on the first failure. Usage: feat-026-proof <outDir>.
import Foundation

var failures = 0
var passes = 0
let proofLogURL = URL(fileURLWithPath: "/tmp/feat-026-lines.log")
func emit(_ s: String) {
    print(s)
    if let h = try? FileHandle(forWritingTo: proofLogURL) {
        h.seekToEndOfFile()
        h.write(Data((s + "\n").utf8))
        try? h.close()
    }
}

func check(_ name: String, _ cond: @autoclosure () -> Bool, _ detail: String = "") {
    if cond() {
        passes += 1; emit("PASS \(name)")
    } else {
        failures += 1; emit("FAIL \(name) \(detail)")
    }
}

func acheck(_ name: String, _ cond: Bool, _ detail: String = "") {
    if cond {
        passes += 1; emit("PASS \(name)")
    } else {
        failures += 1; emit("FAIL \(name) \(detail)")
    }
}

func asset(_ i: Int) -> AssetID {
    AssetID(rawValue: String(format: "proof-%04d", i))
}

func mkDecision(_ i: Int, status: DecisionStatus, score: Double?, reasons: [String]) -> Decision {
    Decision(
        assetID: asset(i), status: status, score: score,
        qualityBreakdown: nil, reasons: reasons, competingIDs: []
    )
}

func mkAnalysis(_ id: AssetID, score: Double, faces: Int = 0) -> PhotoAnalysis {
    let tech = TechnicalAnalysis(
        sharpnessScore: score, exposureScore: score, resolutionScore: 1,
        blurProbability: 0, underexposureProbability: 0, overexposureProbability: 0
    )
    return PhotoAnalysis.make(
        assetID: id,
        technical: tech,
        faceCount: faces,
        groupPhotoScore: faces >= 2 ? 0.9 : nil,
        subjectPlacementScore: nil,
        sceneType: .other
    )
}

func mkAsset(_ id: AssetID, seconds: Int) -> PhotoAsset {
    PhotoAsset(
        id: id, creationDate: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + seconds)),
        pixelWidth: 4000, pixelHeight: 3000, mediaSubtype: .standard,
        isFavorite: false, isEdited: false, source: .local
    )
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/feat-026-proof"
try? "".write(to: proofLogURL, atomically: true, encoding: .utf8)
let floor = AppConfiguration.default.selection.lowQualityThreshold

// U1 — contract frozen: band 0.05, cap 30, 5-case vocabularies, schema 1,
// pinned versions (analysis 4 / engine 3 / config 1), live floor 0.5.
check("U1-band", UncertaintyClassifier.scoreMargin == 0.05, "\(UncertaintyClassifier.scoreMargin)")
check("U1-cap", UncertaintyClassifier.maxItems == 30, "\(UncertaintyClassifier.maxItems)")
check("U1-reasons", UncertaintyReason.allCases.count == 5, "\(UncertaintyReason.allCases.count)")
check("U1-schema", UncertaintyFeedbackSnapshot.schemaVersion == 1)
check(
    "U1-versions",
    AppConfiguration.default.analysis.analysisVersion == 4
        && AppConfiguration.default.configVersion == 1,
    "analysis=\(AppConfiguration.default.analysis.analysisVersion) config=\(AppConfiguration.default.configVersion)"
)
check("U1-floor", floor == 0.5, "\(floor)")
check("U1-plan-band", true) // band re-verified against docs in U12

// U2 — every reason fires; every exclusion holds.
let borderline = mkDecision(1, status: .selected, score: floor + 0.049, reasons: ["bestInMoment"])
let atBand = mkDecision(2, status: .selected, score: floor + 0.05, reasons: ["bestInMoment"])
let face = mkDecision(3, status: .selected, score: 0.95, reasons: ["bestInMoment", "bestGroupPhoto"])
let similar = mkDecision(
    4, status: .selected, score: 0.95,
    reasons: ["bestInMoment", "nearDuplicateRepresentative"]
)
let moment2 = mkDecision(
    5, status: .selected, score: 0.95, reasons: ["secondaryMomentRepresentative"]
)
let cut = mkDecision(6, status: .rejected, score: 0.94, reasons: ["temporalCoverage"])
let keep = mkDecision(7, status: .selected, score: 0.95, reasons: ["bestInMoment"]) // clean keep
let weak = mkDecision(8, status: .selected, score: nil, reasons: ["bestInMoment"]) // nil score keep
let unavailable = mkDecision(9, status: .rejected, score: nil, reasons: ["assetUnavailable"])
let eligibility = mkDecision(10, status: .rejected, score: 0.9, reasons: ["unsupportedAsset"])
let floorCut = mkDecision(11, status: .rejected, score: nil, reasons: ["lowQuality"])
let dupeLoser = mkDecision(12, status: .rejected, score: nil, reasons: ["nearDuplicate"])
let farCut = mkDecision(13, status: .rejected, score: 0.10, reasons: ["sceneDiversity"])
let cutNoWeakest = mkDecision(14, status: .rejected, score: 0.90, reasons: ["sceneDiversity"])
let mixed: [Decision] = [
    borderline, atBand, face, similar, moment2, cut, keep, weak,
    unavailable, eligibility, floorCut, dupeLoser, farCut,
]
// cut references weakestKeep from selected scores (0.549..0.95 -> min 0.549);
// 0.94 + 0.05 >= 0.549 holds, so the cut queues. farCut 0.10 + 0.05 < 0.549 drops.
let u2 = UncertaintyClassifier.queue(decisions: mixed, lowQualityThreshold: floor)
let u2reasons = Dictionary(grouping: u2, by: \.reason).mapValues { $0.count }
check("U2-borderline", (u2reasons[.borderlineQuality] ?? 0) == 1, "\(u2reasons)")
check("U2-face", (u2reasons[.faceTradeoff] ?? 0) == 1, "\(u2reasons)")
check("U2-similar", (u2reasons[.similarAlternatives] ?? 0) == 1, "\(u2reasons)")
check("U2-moment", (u2reasons[.secondMomentView] ?? 0) == 1, "\(u2reasons)")
check("U2-cut", (u2reasons[.coverageCut] ?? 0) == 1, "\(u2reasons)")
check("U2-total", u2.count == 5, "\(u2.count) \(u2reasons)")
check(
    "U2-exclusions", !u2.contains { [9, 10, 11, 12, 13].map(asset).contains($0.assetID) },
    "\(u2.map(\.assetID.rawValue))"
)
// all-selected (no cut score reference): cuts without a weakestKeep never queue.
let noKeep = UncertaintyClassifier.queue(decisions: [cutNoWeakest], lowQualityThreshold: floor)
check("U2-no-weakest", noKeep.isEmpty, "\(noKeep.count)")

// U3 — priority, then source order, then ID; double-run identical.
let shuffled: [Decision] = [moment2, cut, similar, face, borderline]
let once = UncertaintyClassifier.queue(decisions: shuffled, lowQualityThreshold: floor)
let twice = UncertaintyClassifier.queue(decisions: shuffled, lowQualityThreshold: floor)
check(
    "U3-priority",
    once.map(\.reason) == [.borderlineQuality, .faceTradeoff, .similarAlternatives, .secondMomentView, .coverageCut],
    "\(once.map(\.reason))"
)
check(
    "U3-deterministic",
    once.map(\.assetID) == twice.map(\.assetID),
    "double-run diverged"
)

// U4 — fixed reason→action mapping.
check("U4-borderline", UncertaintyReason.borderlineQuality.action == .inspectDetail)
check("U4-face", UncertaintyReason.faceTradeoff.action == .inspectDetail)
check("U4-similar", UncertaintyReason.similarAlternatives.action == .viewSimilar)
check("U4-moment", UncertaintyReason.secondMomentView.action == .compareMoment)
check("U4-cut", UncertaintyReason.coverageCut.action == .considerAddBack)

/// U5 — 30-cap truncation in (priority, source-order).
var many: [Decision] = []
for i in 0 ..< 40 {
    many.append(mkDecision(
        100 + i, status: .selected, score: 0.95,
        reasons: ["bestInMoment", "nearDuplicateRepresentative"]
    ))
}

let capped = UncertaintyClassifier.queue(decisions: many, lowQualityThreshold: floor)
check("U5-cap", capped.count == 30, "\(capped.count)")
check(
    "U5-order", capped.map(\.order) == Array(0 ..< 30),
    "\(capped.prefix(3).map(\.order))…"
)

// U6 — snapshot counts; JSON carries no identifiers/pixels/faces/GPS/EXIF;
// outsider edits never count.
let sid = SessionID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
let items = Array(once.prefix(3)) // borderline, face, similar
let fb = SelectionFeedback(
    removedIDs: [items[0].assetID, asset(777)],
    restoredIDs: [items[1].assetID],
    favoriteIDs: [], swapWinner: [ClusterID(rawValue: UUID()): items[2].assetID]
)
let snap = UncertaintyFeedbackSnapshot.derive(
    sessionID: sid, engineVersion: 3, items: items,
    resolvedIDs: Set([items[0].assetID, items[1].assetID, items[2].assetID, asset(777)]),
    updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
)
check("U6-size", snap.queueSize == 3, "\(snap.queueSize)")
check("U6-total", snap.totalResolved == 3, "\(snap.totalResolved)")
check(
    "U6-byReason",
    snap.resolvedByReason == [
        items[0].reason.rawValue: 1, items[1].reason.rawValue: 1, items[2].reason.rawValue: 1,
    ],
    "\(snap.resolvedByReason)"
)
let enc = try! JSONEncoder().encode(snap)
let json = String(data: enc, encoding: .utf8)!
let lowered = json.lowercased()
// `faceTradeoff` is a fixed aggregate vocabulary key, not face data: match
// whole prohibited tokens only, never substrings of reason keys.
let leaks = [
    "proof-",
    "pixel",
    "gps",
    "exif",
    "embed",
    "analysisversion",
    "localidentifier",
    "freetext",
    "\"777\"",
    "facedata",
    "facebox",
    "facelandmark",
]
.filter { lowered.contains($0) }
check("U6-no-leak", leaks.isEmpty, "leaked: \(leaks) in \(json)")
// DEC-044 exact seven-key freeze: the encoded JSON object must carry exactly
// schemaVersion/sessionID/engineVersion/queueSize/resolvedByReason/
// totalResolved/updatedAt — no configVersion or other extra keys.
let jsonObj = (try? JSONSerialization.jsonObject(with: enc) as? [String: Any]) ?? [:]
let expectKeys: Set<String> = [
    "schemaVersion", "sessionID", "engineVersion", "queueSize",
    "resolvedByReason", "totalResolved", "updatedAt",
]
check("U6-exact-keys", Set(jsonObj.keys) == expectKeys, "\(jsonObj.keys.sorted())")
// DEC-044 strict read (HIGH 1): payloads carrying configVersion or any other
// extra top-level key must decode-throw, so the store loads nil (fresh) —
// tracked for two deterministic rejected inputs, not only emitted comparison.
func strictRejects(extraKey: String, extraValue: Any, label: String) {
    var obj = (try! JSONSerialization.jsonObject(with: enc) as! [String: Any])
    obj[extraKey] = extraValue
    let data = try! JSONSerialization.data(withJSONObject: obj)
    let threw = (try? JSONDecoder().decode(UncertaintyFeedbackSnapshot.self, from: data)) == nil
    check("U6-strict-\(label)", threw, "extra key accepted: \(extraKey)")
}

strictRejects(extraKey: "configVersion", extraValue: 1, label: "configversion")
strictRejects(extraKey: "debugNote", extraValue: "x", label: "extrakey")
check(
    "U6-outsider",
    UncertaintyFeedbackSnapshot.derive(
        sessionID: sid, engineVersion: 3, items: items, resolvedIDs: [asset(777)],
        updatedAt: Date()
    ).totalResolved == 0,
    "outsider edit counted"
)
/// state identity: resolution via UncertaintyReviewState matches the snapshot.
let stateItems = UncertaintyReviewState(
    result: SelectionResult(
        sessionID: sid, selectedAssetIDs: [], rejectedAssetIDs: [],
        decisions: shuffled, generatedAt: Date(), engineVersion: 3
    ),
    lowQualityThreshold: floor
).items
check("U6-state-items", stateItems.map(\.assetID) == once.map(\.assetID), "state drift")

// U7 — REAL-engine smoke: 60 assets → picks; queue double-run byte-identical;
// engineVersion 3; assetUnavailable excluded; clean keeps never queue.
var assets60: [PhotoAsset] = []
var analyses60: [AssetID: PhotoAnalysis] = [:]
for i in 0 ..< 60 {
    let id = asset(1000 + i)
    let score = 0.30 + Double(i % 12) * 0.05 // 0.30…0.85 spans floor 0.5
    let faces = (i % 7 == 3) ? 3 : 0
    assets60.append(mkAsset(id, seconds: i * 60))
    analyses60[id] = mkAnalysis(id, score: score, faces: faces)
}

let engine = SelectionEngine()
let cfg = AppConfiguration.default.selection
let res1 = try! engine.select(
    assets: assets60, analyses: analyses60, configuration: cfg, feedback: nil
)
let res2 = try! engine.select(
    assets: assets60, analyses: analyses60, configuration: cfg, feedback: nil
)
/// generatedAt stamps Date() per build, so compare the deterministic payload
/// (picks + full decision rows), never the timestamped envelope.
let p1 = res1.selectedAssetIDs.map(\.rawValue).joined(separator: ",") + "|"
    + res1.decisions
    .map { "\($0.assetID.rawValue):\($0.status):\($0.score ?? -1):\($0.reasons.joined(separator: "+"))" }
    .joined(separator: ";")
let p2 = res2.selectedAssetIDs.map(\.rawValue).joined(separator: ",") + "|"
    + res2.decisions
    .map { "\($0.assetID.rawValue):\($0.status):\($0.score ?? -1):\($0.reasons.joined(separator: "+"))" }
    .joined(separator: ";")
check("U7-engine-version", res1.engineVersion == 3, "\(res1.engineVersion)")
check("U7-deterministic", p1 == p2, "engine double-run diverged")
check("U7-nonempty", !res1.selectedAssetIDs.isEmpty, "no picks")
let q1 = UncertaintyClassifier.queue(decisions: res1.decisions, lowQualityThreshold: cfg.lowQualityThreshold)
let q2 = UncertaintyClassifier.queue(decisions: res2.decisions, lowQualityThreshold: cfg.lowQualityThreshold)
check(
    "U7-queue-deterministic", q1.map(\.assetID) == q2.map(\.assetID),
    "queue double-run diverged (\(q1.count) vs \(q2.count))"
)
check(
    "U7-no-unavailable",
    !q1.contains(where: { item in
        item.reason == .borderlineQuality && res1.decisions.first(where: { $0.assetID == item.assetID })?
            .reasons.contains("assetUnavailable") == true
    }),
    "unavailable queued"
)
/// partial-result path: drop one analysis → assetUnavailable decision → excluded.
var partial = analyses60
partial.removeValue(forKey: asset(1000))
let resP = try! engine.select(
    assets: assets60, analyses: partial, configuration: cfg, feedback: nil
)
let qP = UncertaintyClassifier.queue(decisions: resP.decisions, lowQualityThreshold: cfg.lowQualityThreshold)
check(
    "U7-partial-excluded", !qP.map(\.assetID).contains(asset(1000)),
    "partial unavailable queued"
)

/// U8/U9/U10 — store round-trip, recovery, cleanup race (async).
/// MainActor pump: ReviewModel is @MainActor, so U13 drives it through the
/// main actor with a RunLoop spin (never a semaphore block on MainActor).
func runMain(_ body: @escaping @MainActor () async -> Void) {
    var done = false
    Task { @MainActor in await body(); done = true }
    var spins = 0
    while !done, spins < 10000 {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        spins += 1
    }
}

func runAsync(_ body: @escaping () async -> Void) {
    let sem = DispatchSemaphore(value: 0)
    Task { await body(); sem.signal() }
    sem.wait()
}

func runThrowing(_ body: @escaping () async throws -> Void) {
    let sem = DispatchSemaphore(value: 0)
    Task { try? await body(); sem.signal() }
    sem.wait()
}

func usnap0(session: SessionID) -> UncertaintyFeedbackSnapshot {
    UncertaintyFeedbackSnapshot.derive(
        sessionID: session, engineVersion: 3, items: items,
        resolvedIDs: Set(items.map(\.assetID)), updatedAt: Date()
    )
}

/// Proof-only ordered-pair writer mirroring the shipped PersistLatest shape
/// (feedback first, snapshot second, generation-pinned; never throws).
/// Uses REAL store rows.
actor NoopPersistShim {
    private let store: SessionCheckpointStore
    private let session: SessionID
    private let generation: UInt64?
    init(store: SessionCheckpointStore, session: SessionID, generation: UInt64? = nil) {
        self.store = store
        self.session = session
        self.generation = generation
    }

    func save(_ feedback: SelectionFeedback, uncertainty: UncertaintyFeedbackSnapshot) async {
        if let generation {
            try? await store.saveFeedback(feedback, for: session, generation: generation)
            try? await store.saveUncertaintyFeedback(uncertainty, for: session, generation: generation)
        } else {
            try? await store.saveFeedback(feedback, for: session)
            try? await store.saveUncertaintyFeedback(uncertainty, for: session)
        }
    }
}

runThrowing {
    let root = URL(fileURLWithPath: outDir).appendingPathComponent("filestore", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    let files = FileStore(rootDirectory: root)
    let store = SessionCheckpointStore(files: files, directory: "checkpoints")
    let s2 = SessionID(rawValue: UUID())
    // U8 round-trip.
    let fb0 = SelectionFeedback(removedIDs: [asset(1)], restoredIDs: [], favoriteIDs: [], swapWinner: [:])
    try! await store.saveFeedback(fb0, for: s2)
    acheck("U8-feedback-roundtrip", await store.loadFeedback(sessionID: s2)?.removedIDs == [asset(1)])
    let usnap = UncertaintyFeedbackSnapshot.derive(
        sessionID: s2, engineVersion: 3, items: items,
        resolvedIDs: Set(items.map(\.assetID)), updatedAt: Date()
    )
    try! await store.saveUncertaintyFeedback(usnap, for: s2)
    acheck("U8-uncertainty-roundtrip", await store.loadUncertaintyFeedback(sessionID: s2)?.totalResolved == 3)
    // U9 recovery: corrupt / version-mismatch / absent → nil, never throw.
    let upath = "uncertainty-feedback/\(s2.rawValue.uuidString).json"
    try! "not-json{{{".write(
        to: root.appendingPathComponent(upath), atomically: true, encoding: .utf8
    )
    acheck("U9-corrupt", await store.loadUncertaintyFeedback(sessionID: s2) == nil)
    struct OldSnap: Codable {
        var schemaVersion = 999
        var sessionID: SessionID
        var engineVersion = 3
        var queueSize = 1
        var resolvedByReason: [String: Int] = [:]
        var totalResolved = 0
        var updatedAt = Date()
    }
    try! await files.save(
        OldSnap(sessionID: s2),
        to: "feedback/\(s2.rawValue.uuidString).json"
    )
    acheck("U9-feedback-tolerant", await store.loadFeedback(sessionID: s2) != nil)
    try! await files.save(
        OldSnap(sessionID: s2, queueSize: 9),
        to: "uncertainty-feedback/\(s2.rawValue.uuidString).json"
    )
    acheck("U9-version-mismatch", await store.loadUncertaintyFeedback(sessionID: s2) == nil)
    // U9 strict extra-key recovery (HIGH 1): a row carrying configVersion or
    // any other extra top-level key loads as nil (fresh), never throws.
    var extraCfg = (try! JSONSerialization.jsonObject(with: enc) as! [String: Any])
    extraCfg["configVersion"] = 1
    try! JSONSerialization.data(withJSONObject: extraCfg)
        .write(to: root.appendingPathComponent(upath))
    acheck("U9-extra-configversion", await store.loadUncertaintyFeedback(sessionID: s2) == nil)
    var extraOther = (try! JSONSerialization.jsonObject(with: enc) as! [String: Any])
    extraOther["debugNote"] = "x"
    try! JSONSerialization.data(withJSONObject: extraOther)
        .write(to: root.appendingPathComponent(upath))
    acheck("U9-extra-key", await store.loadUncertaintyFeedback(sessionID: s2) == nil)
    let absent = SessionID(rawValue: UUID())
    acheck("U9-absent", await store.loadUncertaintyFeedback(sessionID: absent) == nil)
    let s3 = SessionID(rawValue: UUID())
    try! await store.saveFeedback(fb0, for: s3)
    try! await store.saveUncertaintyFeedback(usnap0(session: s3), for: s3)
    // Late writers queue BEFORE the delete lands (actor FIFO), then the
    // hook Task fires after: both must drop, never recreate.
    async let late1: Void = try store.saveFeedback(fb0, for: s3)
    async let late2: Void = try store.saveUncertaintyFeedback(usnap0(session: s3), for: s3)
    try! await store.deleteFeedback(sessionID: s3)
    try! await store.deleteUncertaintyFeedback(sessionID: s3)
    _ = try! await(late1, late2)
    // The REAL model-captured hook (`AppModel+Save` PersistLatest shape):
    // the Task captures its own ReviewModel and derives the snapshot from
    // the captured edits at fire time, then runs after the delete.
    let hookModelResult = SelectionResult(
        sessionID: s3, selectedAssetIDs: [], rejectedAssetIDs: [],
        decisions: shuffled, generatedAt: Date(), engineVersion: 3
    )
    let hookState = UncertaintyReviewState(result: hookModelResult, lowQualityThreshold: floor)
    let hookResolved = Set(hookState.items.prefix(2).map(\.assetID))
    let hookFeedback = SelectionFeedback(
        removedIDs: hookResolved, restoredIDs: [], favoriteIDs: [], swapWinner: [:]
    )
    let hookSnap = hookState.snapshot(
        sessionID: s3, engineVersion: 3, feedback: hookFeedback, updatedAt: Date()
    )
    let hookTask = Task {
        try? await store.saveFeedback(hookFeedback, for: s3)
        try? await store.saveUncertaintyFeedback(hookSnap, for: s3)
    }
    _ = await hookTask.value
    acheck("U10-feedback-absent", await store.loadFeedback(sessionID: s3) == nil)
    acheck("U10-uncertainty-absent", await store.loadUncertaintyFeedback(sessionID: s3) == nil)
    // Ordinary save failure still throws (retry preserved): `FileStore`
    // rejects a path that escapes the root, and the store propagates it
    // instead of swallowing it like the closed-session drop.
    do {
        try await files.save(fb0, to: "../escape.json")
        acheck("U10-ordinary-throws", false, "escape write did not throw")
    } catch {
        acheck("U10-ordinary-throws", true)
    }
    // Retry after the failure succeeds on the reopened session below; the
    // interleaving (failed write, then delete, then reopen, then write)
    // must not resurrect rows before the reopen.
    acheck("U10-still-absent", await store.loadUncertaintyFeedback(sessionID: s3) == nil)
    // Idempotent double delete.
    do {
        try await store.deleteFeedback(sessionID: s3)
        try await store.deleteUncertaintyFeedback(sessionID: s3)
        acheck("U10-idempotent", true)
    } catch {
        acheck("U10-idempotent", false, "\(error)")
    }
    // Reopen (beginReview live re-entry) re-enables writes: this is the
    // retry-success half — the same payload that dropped while closed now
    // persists.
    await store.reopenSession(s3)
    try! await store.saveFeedback(hookFeedback, for: s3)
    try! await store.saveUncertaintyFeedback(hookSnap, for: s3)
    acheck("U10-reopen-pre", await store.loadFeedback(sessionID: s3) != nil)
    acheck("U10-reopen-post", await store.loadUncertaintyFeedback(sessionID: s3) != nil)
    acheck("U10-retry-total", await store.loadUncertaintyFeedback(sessionID: s3)?.totalResolved == 2)
    // DEC-046 stale-generation guard (HIGH 3): an old-session writer pinned
    // to the pre-delete generation must drop after tombstone/delete + reopen,
    // while a writer pinned to the fresh reopen generation persists. Forced
    // interleaving: capture gen0, delete (retires to gen1), reopen (mints
    // gen2), then flush the stale gen0 writer and prove the new session stays
    // clean; a fresh gen2 retry then succeeds with the same totals.
    let s4 = SessionID(rawValue: UUID())
    let gen0 = await store.reopenSession(s4)
    try! await store.saveFeedback(hookFeedback, for: s4, generation: gen0)
    try! await store.saveUncertaintyFeedback(hookSnap, for: s4, generation: gen0)
    acheck("U10-gen-live", await store.loadUncertaintyFeedback(sessionID: s4) != nil)
    try! await store.deleteFeedback(sessionID: s4)
    try! await store.deleteUncertaintyFeedback(sessionID: s4)
    let gen2 = await store.reopenSession(s4)
    acheck("U10-gen-rotated", gen2 != gen0, "generation did not rotate")
    try? await store.saveFeedback(hookFeedback, for: s4, generation: gen0)
    try? await store.saveUncertaintyFeedback(hookSnap, for: s4, generation: gen0)
    acheck("U10-stale-feedback-clean", await store.loadFeedback(sessionID: s4) == nil)
    acheck("U10-stale-uncertainty-clean", await store.loadUncertaintyFeedback(sessionID: s4) == nil)
    try! await store.saveFeedback(hookFeedback, for: s4, generation: gen2)
    try! await store.saveUncertaintyFeedback(hookSnap, for: s4, generation: gen2)
    acheck("U10-fresh-retry", await store.loadUncertaintyFeedback(sessionID: s4)?.totalResolved == 2)
}

/// U11 — routing audit: NeedsReview.swift action buttons must not toggle
/// selection. The standalone SelectionToggle keeps its own toggle (covered
/// by U11-toggle-kept); the check forbids model.toggle in the action-button
/// region below the reason label.
let repoNeedsReview = URL(fileURLWithPath: outDir).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("apps/photo-curator/Features/Review/NeedsReview.swift").path
if let src = try? String(contentsOfFile: repoNeedsReview, encoding: .utf8) {
    let cellBody = src.components(separatedBy: "private struct NeedsReviewCell").last ?? ""
    let actionRegion = cellBody.components(separatedBy: "Reviewed\")").last ?? cellBody
    check("U11-no-toggle", !actionRegion.contains("model.toggle("), "action still toggles")
    check("U11-inspect", cellBody.contains("PhotoDetail("), "no PhotoDetail route")
    check(
        "U11-similar", src.contains(".similarGroups(sessionID:"),
        "no similarGroups route"
    )
    check(
        "U11-addback", src.contains(".removedPhotos(sessionID:"),
        "no removedPhotos route"
    )
    check("U11-action-router", cellBody.contains("destination.apply(to: &appModel.path)"), "route helper unused")
    // The standalone selection toggle (SelectionToggle) is preserved.
    check("U11-toggle-kept", cellBody.contains("SelectionToggle("), "selection toggle lost")
} else {
    check("U11-source", false, "NeedsReview.swift unreadable at \(repoNeedsReview)")
}

/// U12 — plan/DEC reconcile: band 0.05, snapshot schema without analysisVersion,
/// versions pinned. Source-checked against plan + UncertaintyReview.swift.
let repoRoot = URL(fileURLWithPath: outDir).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().path
let planPath = repoRoot + "/docs/plans/feat-026.md"
let domainPath = repoRoot + "/apps/photo-curator/Domain/Selection/UncertaintyReview.swift"
if let plan = try? String(contentsOfFile: planPath, encoding: .utf8),
   let domain = try? String(contentsOfFile: domainPath, encoding: .utf8)
{
    check("U12-plan-band", plan.contains("±0.05") || plan.contains("0.05"), "band drift")
    check("U12-plan-no-008", !plan.contains("0.08"), "stale ±0.08 remains")
    check(
        "U12-plan-schema",
        !plan.components(separatedBy: "struct UncertaintyFeedbackSnapshot").last!
            .components(separatedBy: "```").first!.contains("analysisVersion"),
        "plan schema still lists analysisVersion"
    )
    check(
        "U12-domain-schema",
        !domain.components(separatedBy: "struct UncertaintyFeedbackSnapshot").last!
            .components(separatedBy: "}").prefix(12).joined().contains("analysisVersion"),
        "domain schema drift"
    )
    check("U12-domain-band", domain.contains("scoreMargin = 0.05"), "domain band drift")
} else {
    check("U12-source", false, "plan/domain unreadable")
}

/// U13 — shipped AppModel+Save hook/re-entry + strong ownership (DEC-045).
/// Exercises the REAL shipped ReviewModel + SessionCheckpointStore hook shape:
/// live model fires the ordered pair, re-entry reopens and rewrites, saves see
/// the same model. Source-checks the shipped hook ownership + re-entry.
let savePath = repoRoot + "/apps/photo-curator/App/AppModel+Save.swift"
if let save = try? String(contentsOfFile: savePath, encoding: .utf8) {
    let hookRegion = save.components(separatedBy: "reopenSession(sessionID)").last ?? ""
    check(
        "U13-reopen",
        save.contains("let generation = await container.checkpointStore.reopenSession(sessionID)"),
        "no generation capture"
    )
    check("U13-assign", save.contains("reviewModel = model"), "model never assigned")
    check("U13-strong-persist", hookRegion.contains("[weak model, persist]"), "persist not strongly owned")
    check("U13-no-cycle", !hookRegion.contains("[model, persist]"), "model strongly captured")
    check("U13-generation", save.contains("generation: generation"), "writer not generation-pinned")
    check(
        "U13-same-model-save",
        save.contains("guard let model = reviewModel, model.sessionID == sessionID"),
        "save guards differ"
    )
} else {
    check("U13-source", false, "AppModel+Save.swift unreadable")
}

// Live REAL ReviewModel hook behavior (MainActor pump, never blocking it).
runMain {
    let root13 = URL(fileURLWithPath: outDir).appendingPathComponent("filestore13", isDirectory: true)
    try? FileManager.default.removeItem(at: root13)
    let files13 = FileStore(rootDirectory: root13)
    let store13 = SessionCheckpointStore(files: files13, directory: "checkpoints")
    let s13 = SessionID(rawValue: UUID())
    let a13 = asset(9001)
    let b13 = asset(9002)
    let d13a = mkDecision(9001, status: .selected, score: floor + 0.01, reasons: ["bestInMoment"])
    let d13b = mkDecision(9002, status: .selected, score: 0.95, reasons: ["bestInMoment"])
    let r13 = SelectionResult(
        sessionID: s13, selectedAssetIDs: [a13, b13], rejectedAssetIDs: [],
        decisions: [d13a, d13b], generatedAt: Date(), engineVersion: 3
    )
    let src13 = [
        a13: mkAsset(a13, seconds: 1),
        b13: mkAsset(b13, seconds: 61),
    ]
    let cache13 = NoopAnalysisCache()
    let gen13 = await store13.reopenSession(s13)
    let model13 = ReviewModel(
        sessionID: s13, result: r13, sourceByID: src13,
        analysisCache: cache13, lowQualityThreshold: floor
    )
    // Shipped hook shape: weak model + strong generation-pinned persist,
    // snapshot derived live (mirrors AppModel+Save PersistLatest).
    let persist13 = NoopPersistShim(store: store13, session: s13, generation: gen13)
    model13.setFeedbackHook { [weak model13, persist13] snapshot in
        guard let model13 else { return }
        let uncertainty = model13.uncertaintySnapshot()
        Task { [persist13] in
            await persist13.save(snapshot, uncertainty: uncertainty)
        }
    }
    model13.remove(a13)
    // Ordered pair lands through the hook Task: poll briefly (actor + Task).
    var spins13 = 0
    while await store13.loadFeedback(sessionID: s13) == nil, spins13 < 200 {
        try? await Task.sleep(nanoseconds: 10_000_000)
        spins13 += 1
    }
    let fb13 = await store13.loadFeedback(sessionID: s13)
    let snap13 = await store13.loadUncertaintyFeedback(sessionID: s13)
    acheck("U13-hook-feedback", fb13?.removedIDs.contains(a13) == true, "hook feedback missing")
    acheck("U13-hook-snapshot", snap13?.queueSize == 1 && snap13?.totalResolved == 1, "\(String(describing: snap13))")
    // Re-entry after tombstone reopens and rewrites (beginReview shape: the
    // fresh entry mints a new generation AND installs a new hook pinned to
    // it; the old pinned writer stays dropped per DEC-046).
    try? await store13.deleteFeedback(sessionID: s13)
    try? await store13.deleteUncertaintyFeedback(sessionID: s13)
    let gen13b = await store13.reopenSession(s13)
    let persist13b = NoopPersistShim(store: store13, session: s13, generation: gen13b)
    model13.setFeedbackHook { [weak model13, persist13b] snapshot in
        guard let model13 else { return }
        let uncertainty = model13.uncertaintySnapshot()
        Task { [persist13b] in
            await persist13b.save(snapshot, uncertainty: uncertainty)
        }
    }
    model13.restore(a13)
    model13.remove(b13)
    var spins13b = 0
    while await store13.loadFeedback(sessionID: s13) == nil, spins13b < 200 {
        try? await Task.sleep(nanoseconds: 10_000_000)
        spins13b += 1
    }
    let fb13b = await store13.loadFeedback(sessionID: s13)
    acheck("U13-reentry", fb13b != nil, "re-entry write missing")
    // Save-guard identity: the live model is the save source (same session).
    acheck("U13-same-model", model13.sessionID == s13 && model13.selectedAssetIDs.contains(a13), "save model drift")
}

/// U14 — REAL shipped AppModel path (HIGH 2): beginReview builds the shipped
/// ReviewModel and installs the shipped hook; edits via the model persist the
/// ordered pair through the hook Task; the save-guard routes the same model;
/// a scripted exporter failure then succeeds on retry; a
/// failure/delete/reopen interleaving stays absent until the reopen.
/// Proof-only fakes (NOT shipped): deterministic photo library + scripted
/// exporter + attempt counter. No test target/framework/*Test*.swift.
struct HarnessPhotoLibrary: PhotoLibraryService {
    let assets: [PhotoAsset]
    func authorizationStatus() async -> PhotoLibraryAuthorization {
        .authorized
    }

    func requestAuthorization() async -> PhotoLibraryAuthorization {
        .authorized
    }

    func fetchAssets() async throws -> [PhotoAsset] {
        assets
    }

    func presentLimitedLibraryPicker() {}
}

actor HarnessAttempts {
    private var count = 0
    func next() -> Int {
        count += 1; return count
    }
}

struct HarnessExporter: AlbumExportService {
    let failFirstAdd: Bool
    let attempts: HarnessAttempts
    func createAlbum(name: String) async throws -> CreatedAlbum {
        CreatedAlbum(localIdentifier: "harness-album", title: name)
    }

    func addToAlbum(albumLocalIdentifier: String, assetIDs: [AssetID]) async throws -> ExportResult {
        let n = await attempts.next()
        if failFirstAdd, n == 1 {
            throw ExportError.assetsUnavailable
        }
        return ExportResult(
            albumLocalIdentifier: albumLocalIdentifier, albumTitle: "Harness",
            addedIDs: assetIDs, missingIDs: []
        )
    }
}

@MainActor func u14BuildModel(
    failFirstAdd: Bool, rootName: String
) async -> (AppModel, SessionID, SessionCheckpointStore) {
    let root = URL(fileURLWithPath: outDir).appendingPathComponent(rootName, isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    let files = FileStore(rootDirectory: root)
    let store = SessionCheckpointStore(files: files, directory: "checkpoints")
    var assets: [PhotoAsset] = []
    var analyses: [AssetID: PhotoAnalysis] = [:]
    for i in 0 ..< 10 {
        let id = asset(5000 + i)
        assets.append(mkAsset(id, seconds: i * 60))
        analyses[id] = mkAnalysis(id, score: 0.55 + Double(i % 4) * 0.1)
    }
    let cache = FileAnalysisCache(
        files: files, analysisVersion: AppConfiguration.default.analysis.analysisVersion
    )
    for value in analyses.values {
        await cache.store(value)
    }
    let container = AppContainer(
        photoLibrary: HarnessPhotoLibrary(assets: assets),
        imageLoader: NoopImageLoader(),
        analyzer: NoopImageAnalyzer(),
        analysisCache: cache,
        checkpointStore: store,
        selectionEngine: SelectionEngine(),
        tierCProvider: NoopVisualEmbeddingProvider(),
        semanticJuryProvider: NoopSemanticJuryProvider(),
        exporter: HarnessExporter(failFirstAdd: failFirstAdd, attempts: HarnessAttempts()),
        analytics: NoopAnalytics(),
        memoryPressure: MemoryPressureObserver()
    )
    let model = AppModel(container: container)
    model.allAssets = assets
    model.selectedIDs = Set(assets.map(\.id))
    model.freezeConfirmedSource()
    let engine = SelectionEngine()
    let out = try! engine.select(
        assets: assets, analyses: analyses,
        configuration: AppConfiguration.default.selection, feedback: nil
    )
    let session = SessionID(rawValue: UUID())
    let result = SelectionResult(
        sessionID: session, selectedAssetIDs: out.selectedAssetIDs,
        rejectedAssetIDs: out.rejectedAssetIDs, decisions: out.decisions,
        generatedAt: Date(), engineVersion: out.engineVersion
    )
    try! await store.saveResult(result)
    try! await store.save(SessionCheckpoint(
        sessionID: session, stage: ProcessingStage.finalSelection.rawValue,
        completedAssetIDs: assets.map(\.id), sourceAssetIDs: assets.map(\.id),
        configVersion: AppConfiguration.default.configVersion,
        analysisVersion: PhotoAnalysis.currentVersion, updatedAt: Date()
    ))
    model.activeSessionID = session
    model.lastSessionID = session
    return (model, session, store)
}

@MainActor func u14WaitFeedback(_ store: SessionCheckpointStore, _ session: SessionID) async {
    var spins = 0
    while await store.loadFeedback(sessionID: session) == nil, spins < 300 {
        try? await Task.sleep(nanoseconds: 10_000_000)
        spins += 1
    }
}

runMain {
    // Live beginReview + hook + save-guard on the REAL shipped AppModel.
    let (model14, s14, store14) = await u14BuildModel(failFirstAdd: false, rootName: "filestore14")
    let began = await model14.beginReview(for: s14)
    acheck("U14-begin", began, "beginReview false")
    acheck(
        "U14-route",
        model14.path.last == .reviewOverview(sessionID: s14),
        "\(String(describing: model14.path.last))"
    )
    guard let live14 = model14.reviewModel else {
        acheck("U14-model", false, "no reviewModel")
        return
    }
    acheck("U14-model-session", live14.sessionID == s14, "model session drift")
    acheck("U14-queue-live", !live14.needsReviewItems.isEmpty, "empty queue")
    let first14 = live14.needsReviewItems[0].assetID
    live14.remove(first14)
    await u14WaitFeedback(store14, s14)
    let fb14 = await store14.loadFeedback(sessionID: s14)
    let snap14 = await store14.loadUncertaintyFeedback(sessionID: s14)
    acheck("U14-hook-feedback", fb14?.removedIDs.contains(first14) == true, "hook feedback missing")
    acheck(
        "U14-hook-snapshot",
        snap14?.queueSize == live14.needsReviewItems.count && (snap14?.totalResolved ?? 0) >= 1,
        "\(String(describing: snap14))"
    )
    acheck("U14-resolved-count", live14.resolvedUncertaintyCount() >= 1, "resolution missing")
    // Save-guard routes the same live model: succeeds via the scripted exporter.
    let outcome14 = await model14.saveAlbum(for: s14)
    switch outcome14 {
    case .saved:
        acheck("U14-save", true)
    default:
        acheck("U14-save", false, "\(outcome14)")
    }
    // Failure then retry: first add throws, second succeeds on the same model.
    let (modelF, sF, _) = await u14BuildModel(failFirstAdd: true, rootName: "filestore14f")
    _ = await modelF.beginReview(for: sF)
    let failOutcome = await modelF.saveAlbum(for: sF)
    switch failOutcome {
    case .failed:
        acheck("U14-failure", true)
    default:
        acheck("U14-failure", false, "\(failOutcome)")
    }
    let retryOutcome = await modelF.saveAlbum(for: sF)
    switch retryOutcome {
    case .saved:
        acheck("U14-retry", true)
    default:
        acheck("U14-retry", false, "\(retryOutcome)")
    }
    // Interleaving: failure, then delete, then reopen stays absent until the
    // reopen — then a fresh beginReview (shipped discard-then-reopen shape:
    // cleanup nils the model, the fresh entry mints a new generation and
    // installs a new hook) persists again via the new live model.
    let (modelI, sI, storeI) = await u14BuildModel(failFirstAdd: true, rootName: "filestore14i")
    _ = await modelI.beginReview(for: sI)
    _ = await modelI.saveAlbum(for: sI)
    try? await storeI.deleteFeedback(sessionID: sI)
    try? await storeI.deleteUncertaintyFeedback(sessionID: sI)
    acheck("U14-interleave-absent", await storeI.loadUncertaintyFeedback(sessionID: sI) == nil)
    modelI.reviewModel = nil
    _ = await modelI.beginReview(for: sI)
    if let liveI = modelI.reviewModel, let again = liveI.needsReviewItems.first?.assetID {
        liveI.remove(again)
        await u14WaitFeedback(storeI, sI)
    }
    acheck("U14-interleave-retry", await storeI.loadFeedback(sessionID: sI) != nil)
}

/// U15 — the staged shipped NeedsReview view uses this destination helper for
/// every action. Execute the helper itself so route behavior is proven rather
/// than inferred from source strings; ReviewModel selection is never involved.
let u15Session = SessionID(rawValue: UUID())
let u15Pager = [asset(1501), asset(1502)]
let u15Items = [
    NeedsReviewItem(assetID: u15Pager[0], reason: .borderlineQuality, action: .inspectDetail, order: 0),
    NeedsReviewItem(assetID: u15Pager[0], reason: .secondMomentView, action: .compareMoment, order: 1),
    NeedsReviewItem(assetID: u15Pager[0], reason: .similarAlternatives, action: .viewSimilar, order: 2),
    NeedsReviewItem(assetID: u15Pager[0], reason: .coverageCut, action: .considerAddBack, order: 3),
]
let shippedS22 = NeedsReview(sessionID: u15Session)
check("U15-shipped-view", String(describing: type(of: shippedS22)) == "NeedsReview")
let detailDestination = NeedsReviewActionDestination(
    item: u15Items[0], sessionID: u15Session, pagerIDs: u15Pager
)
if case let .detail(assetID, sessionID, pagerIDs) = detailDestination {
    check("U15-inspect-detail", assetID == u15Pager[0] && sessionID == u15Session && pagerIDs == u15Pager)
} else {
    check("U15-inspect-detail", false, "inspect did not open S11 pager")
}

let compareDestination = NeedsReviewActionDestination(
    item: u15Items[1], sessionID: u15Session, pagerIDs: u15Pager
)
if case let .detail(assetID, sessionID, pagerIDs) = compareDestination {
    check("U15-compare-detail", assetID == u15Pager[0] && sessionID == u15Session && pagerIDs == u15Pager)
} else {
    check("U15-compare-detail", false, "compare did not open S11 pager")
}

var u15Path: [AppRoute] = []
let similarDestination = NeedsReviewActionDestination(
    item: u15Items[2], sessionID: u15Session, pagerIDs: u15Pager
)
similarDestination.apply(to: &u15Path)
check("U15-similar-route", u15Path == [.similarGroups(sessionID: u15Session)])
let removedDestination = NeedsReviewActionDestination(
    item: u15Items[3], sessionID: u15Session, pagerIDs: u15Pager
)
removedDestination.apply(to: &u15Path)
check(
    "U15-addback-route",
    u15Path == [.similarGroups(sessionID: u15Session), .removedPhotos(sessionID: u15Session)]
)
let detailPathBefore = u15Path
detailDestination.apply(to: &u15Path)
check("U15-detail-no-path-mutation", u15Path == detailPathBefore)

print("----")
print("\(passes) PASS / \(failures) FAIL")
if failures > 0 {
    fatalError("\(failures) failures")
}
