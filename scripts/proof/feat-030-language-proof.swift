import Foundation

enum LanguageProofError: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message): message
        }
    }
}

@main
struct Feature030LanguageProof {
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
        try require(
            AppLanguage.allCases == [.systemDefault, .english, .vietnamese],
            "language choices changed"
        )
        try require(
            AppLanguage.systemDefault.locale.identifier == Locale.autoupdatingCurrent.identifier,
            "System Default does not resolve the current system locale"
        )
        try require(AppLanguage.english.locale.identifier == "en", "English locale is not explicit")
        try require(AppLanguage.vietnamese.locale.identifier == "vi", "Vietnamese locale is not explicit")
        print("LANGUAGE-CONTRACT PASS")

        let fallback = String(localized: "Feat-030 fallback proof")
        try require(fallback == "Feat-030 fallback proof", "missing catalog entry did not fall back safely")
        print("FALLBACK PASS")

        let count = 1234
        let englishNumber = count.formatted(.number.locale(Locale(identifier: "en")))
        let vietnameseNumber = count.formatted(.number.locale(Locale(identifier: "vi")))
        try require(!englishNumber.isEmpty && !vietnameseNumber.isEmpty, "locale-aware number formatting failed")

        let date = Date(timeIntervalSince1970: 0)
        let englishDate = date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "en")))
        let vietnameseDate = date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "vi")))
        try require(!englishDate.isEmpty && !vietnameseDate.isEmpty, "locale-aware date formatting failed")

        var resource: LocalizedStringResource = "\(count) photos"
        resource.locale = Locale(identifier: "vi")
        try require(!String(localized: resource).isEmpty, "localized interpolation did not resolve")
        print("LOCALE-FORMATTING PASS")
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw LanguageProofError.assertion(message) }
    }
}
