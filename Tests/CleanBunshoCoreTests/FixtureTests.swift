import XCTest
@testable import CleanBunshoCore

/// Fixtures/cases.json のテストケース。Windows 版・参照実装（tools/reference-cleaner.mjs）と共通
struct FixtureFile: Decodable {
    let version: Int
    let cases: [FixtureCase]
}

struct FixtureCase: Decodable {
    let name: String
    let input: String
    let expected: String
    let removed: Int
    let replaced: Int
    let options: [String: Bool]
}

final class FixtureTests: XCTestCase {
    func loadCases() throws -> [FixtureCase] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "cases", withExtension: "json", subdirectory: "Fixtures"),
            "Fixtures/cases.json が見つかりません"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureFile.self, from: data).cases
    }

    func testAllFixtures() throws {
        let cases = try loadCases()
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            let r = Cleaner.clean(c.input, options: CleanOptions(overrides: c.options))
            // String の == は正規化して比べるため、スカラー単位で比べる
            XCTAssertTrue(
                r.text.unicodeScalars.elementsEqual(c.expected.unicodeScalars),
                "\(c.name): 結果が違います \(debug(r.text)) != \(debug(c.expected))"
            )
            XCTAssertEqual(r.removedCount, c.removed, "\(c.name): 削除数")
            XCTAssertEqual(r.replacedCount, c.replaced, "\(c.name): 置換数")
            XCTAssertEqual(r.changed, !c.input.unicodeScalars.elementsEqual(c.expected.unicodeScalars), "\(c.name): changed")
        }
    }

    private func debug(_ s: String) -> String {
        s.unicodeScalars.map { $0.isASCII && $0.value >= 0x20 ? String($0) : "\\u{\(String($0.value, radix: 16))}" }.joined()
    }
}

final class CleanerTests: XCTestCase {
    func testDefaults() {
        XCTAssertTrue(CleanOptions.default[.zeroWidth])
        XCTAssertFalse(CleanOptions.default[.ideographicSpace])
        XCTAssertFalse(CleanOptions.default[.curlyQuotes])
    }

    func testOptionsRoundTripKeepsDefaultsForUnknownRules() throws {
        var o = CleanOptions()
        o[.dashes] = true
        let data = try JSONEncoder().encode(o)
        let back = try JSONDecoder().decode(CleanOptions.self, from: data)
        XCTAssertEqual(back, o)
        XCTAssertTrue(back[.dashes])
        XCTAssertTrue(back[.zeroWidth])
    }

    func testIdempotent() {
        let input = "\u{FEFF}  a\u{200B}b\u{00A0}c  \r\n\n\n\n\nd\u{2028}e  "
        let opts = CleanOptions([.collapseBlankLines: true])
        let once = Cleaner.clean(input, options: opts)
        let twice = Cleaner.clean(once.text, options: opts)
        XCTAssertFalse(twice.changed)
        XCTAssertEqual(twice.totalCount, 0)
    }

    func testSummaryMessage() {
        XCTAssertEqual(Cleaner.clean("a\u{200B}\u{200B}\u{200B}b").summaryMessage, "3個を削除しました")
        XCTAssertNil(Cleaner.clean("abc").summaryMessage)
    }

    func testSummarize() {
        let r = Cleaner.clean("a\u{200B}b\u{200B}c\u{00A0}👨\u{200D}👩")
        let items = Cleaner.summarize(r.findings)
        XCTAssertEqual(items.first?.code, "U+200B")
        XCTAssertEqual(items.first?.count, 2)
        XCTAssertEqual(items.count, 2) // 絵文字の ZWJ は内訳に出さない
    }

    func testCodeLabel() {
        XCTAssertEqual(Cleaner.codeLabel("\u{AD}"), "U+00AD")
        XCTAssertEqual(Cleaner.codeLabel("\u{E0041}"), "U+E0041")
    }
}
