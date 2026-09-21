import Foundation

enum QwenPairResponseValidationError: Error, Equatable, Sendable {
    case responseTooLarge
    case fencedResponse
    case malformedJSON
    case duplicateKey(String)
    case invalidKeys
    case invalidField(String)
    case invalidEnum(String)
    case duplicateReason
    case tooManyReasons
}

struct QwenPairResponse: Equatable, Sendable {
    let relation: QualityPairRelation
    let preference: QualityPairPreference
    let reasons: [QualityPairReason]
}

enum QwenPairResponseValidator {
    static let maxResponseBytes = 4 * 1024

    static func validate(_ raw: String) throws -> QwenPairResponse {
        guard raw.utf8.count <= maxResponseBytes else {
            throw QwenPairResponseValidationError.responseTooLarge
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("```") else {
            throw QwenPairResponseValidationError.fencedResponse
        }
        guard trimmed.first == "{", trimmed.last == "}" else {
            throw QwenPairResponseValidationError.malformedJSON
        }

        let keys = try TopLevelKeyScanner.keys(in: trimmed)
        var uniqueKeys = Set<String>()
        for key in keys where !uniqueKeys.insert(key).inserted {
            throw QwenPairResponseValidationError.duplicateKey(key)
        }
        guard uniqueKeys == ["relation", "preference", "reasons"] else {
            throw QwenPairResponseValidationError.invalidKeys
        }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let fields = object as? [String: Any]
        else {
            throw QwenPairResponseValidationError.malformedJSON
        }

        guard let relationRaw = fields["relation"] as? String else {
            throw QwenPairResponseValidationError.invalidField("relation")
        }
        guard let relation = QualityPairRelation(rawValue: relationRaw) else {
            throw QwenPairResponseValidationError.invalidEnum(relationRaw)
        }

        guard let preferenceRaw = fields["preference"] as? String else {
            throw QwenPairResponseValidationError.invalidField("preference")
        }
        guard let preference = QualityPairPreference(rawValue: preferenceRaw) else {
            throw QwenPairResponseValidationError.invalidEnum(preferenceRaw)
        }

        guard let reasonValues = fields["reasons"] as? [Any] else {
            throw QwenPairResponseValidationError.invalidField("reasons")
        }
        guard reasonValues.count <= 3 else {
            throw QwenPairResponseValidationError.tooManyReasons
        }

        var reasons: [QualityPairReason] = []
        var uniqueReasons = Set<QualityPairReason>()
        for value in reasonValues {
            guard let rawReason = value as? String,
                  let reason = QualityPairReason(rawValue: rawReason)
            else {
                throw QwenPairResponseValidationError.invalidEnum("reason")
            }
            guard uniqueReasons.insert(reason).inserted else {
                throw QwenPairResponseValidationError.duplicateReason
            }
            reasons.append(reason)
        }

        return QwenPairResponse(relation: relation, preference: preference, reasons: reasons)
    }
}

private enum TopLevelKeyScanner {
    static func keys(in input: String) throws -> [String] {
        let bytes = Array(input.utf8)
        var index = 0
        skipWhitespace(bytes, index: &index)
        guard consume(123, bytes, index: &index) else {
            throw QwenPairResponseValidationError.malformedJSON
        }

        var keys: [String] = []
        while true {
            skipWhitespace(bytes, index: &index)
            guard index < bytes.count, bytes[index] == 34 else {
                throw QwenPairResponseValidationError.malformedJSON
            }
            let start = index
            try skipString(bytes, index: &index)
            guard let key = decodeString(bytes[start ..< index]) else {
                throw QwenPairResponseValidationError.malformedJSON
            }
            keys.append(key)

            skipWhitespace(bytes, index: &index)
            guard consume(58, bytes, index: &index) else {
                throw QwenPairResponseValidationError.malformedJSON
            }
            try skipValue(bytes, index: &index)
            skipWhitespace(bytes, index: &index)

            if consume(44, bytes, index: &index) {
                continue
            }
            guard consume(125, bytes, index: &index) else {
                throw QwenPairResponseValidationError.malformedJSON
            }
            skipWhitespace(bytes, index: &index)
            guard index == bytes.count else {
                throw QwenPairResponseValidationError.malformedJSON
            }
            return keys
        }
    }

    private static func skipValue(_ bytes: [UInt8], index: inout Int) throws {
        var depth = 0
        while index < bytes.count {
            switch bytes[index] {
            case 34:
                try skipString(bytes, index: &index)
            case 91, 123:
                depth += 1
                index += 1
            case 93, 125:
                guard depth > 0 else { return }
                depth -= 1
                index += 1
            case 44 where depth == 0:
                return
            default:
                index += 1
            }
        }
    }

    private static func skipString(_ bytes: [UInt8], index: inout Int) throws {
        guard consume(34, bytes, index: &index) else {
            throw QwenPairResponseValidationError.malformedJSON
        }
        while index < bytes.count {
            if bytes[index] == 92 {
                index += 2
            } else if bytes[index] == 34 {
                index += 1
                return
            } else {
                index += 1
            }
        }
        throw QwenPairResponseValidationError.malformedJSON
    }

    private static func decodeString(_ bytes: ArraySlice<UInt8>) -> String? {
        guard let value = try? JSONSerialization.jsonObject(
            with: Data(bytes), options: [.fragmentsAllowed]
        ) as? String else {
            return nil
        }
        return value
    }

    private static func consume(_ byte: UInt8, _ bytes: [UInt8], index: inout Int) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private static func skipWhitespace(_ bytes: [UInt8], index: inout Int) {
        while index < bytes.count, bytes[index] == 32 || bytes[index] == 9 || bytes[index] == 10 || bytes[index] == 13 {
            index += 1
        }
    }
}
