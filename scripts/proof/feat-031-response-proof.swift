import Foundation

@main
struct Feat031ResponseProof {
    static func main() throws {
        try expectValid()
        try expectRejected("```json\n{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[]}\n```")
        try expectRejected("[{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[]}]")
        try expectRejected("{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[],\"extra\":1}")
        try expectRejected(
            "{\"relation\":\"retake\",\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[]}"
        )
        try expectRejected("{\"relation\":\"retake\",\"preference\":\"unknown\",\"reasons\":[]}")
        try expectRejected(
            "{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[\"composition\",\"composition\"]}"
        )
        try expectRejected(
            "{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[\"composition\",\"action\",\"framing\",\"redundant\"]}"
        )
        try expectRejected(
            "{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[],\"x\":\""
                + String(repeating: "a", count: 4097) + "\"}"
        )
        print("RESPONSE-VALIDATION PASS")
    }

    private static func expectValid() throws {
        let response = try QwenPairResponseValidator.validate(
            "{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[\"composition\",\"subjectVisibility\"]}"
        )
        guard response.relation == .retake,
              response.preference == .chooseA,
              response.reasons == [.composition, .subjectVisibility]
        else {
            throw NSError(domain: "Feat031ResponseProof", code: 1)
        }
    }

    private static func expectRejected(_ raw: String) throws {
        do {
            _ = try QwenPairResponseValidator.validate(raw)
            throw NSError(domain: "Feat031ResponseProof", code: 2)
        } catch is QwenPairResponseValidationError {
            return
        }
    }
}
