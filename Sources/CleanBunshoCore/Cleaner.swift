import Foundation

/// 検出した1文字分の情報
public struct Finding: Sendable, Equatable {
    /// 入力文字列の何番目の Unicode スカラーか
    public let index: Int
    public let scalar: Unicode.Scalar
    public let rule: Rule
    /// 絵文字の結合などのため残す文字
    public let isProtected: Bool

    public var code: String { Cleaner.codeLabel(scalar) }
}

/// 処理結果
public struct CleanResult: Sendable, Equatable {
    public let text: String
    /// 削除した文字数（ゼロ幅・書字方向・タグ・制御文字）
    public let removedCount: Int
    /// 置き換えた文字数（空白・行区切り・クォート・ダッシュ）
    public let replacedCount: Int
    /// ルールごとの件数
    public let breakdown: [Rule: Int]
    public let findings: [Finding]
    /// 元の文章から変わったか（変わっていなければクリップボードを書き換えない）
    public let changed: Bool

    public var totalCount: Int { removedCount + replacedCount }

    /// 通知用の文言。何も消していなければ nil
    public var summaryMessage: String? {
        switch (removedCount, replacedCount) {
        case (0, 0): return nil
        case (let r, 0): return "\(r)個を削除しました"
        case (0, let p): return "\(p)個を置き換えました"
        case (let r, let p): return "\(r)個を削除し、\(p)個を置き換えました"
        }
    }
}

/// ウィンドウの内訳表示用の集計
public struct SummaryItem: Sendable, Identifiable, Equatable {
    public var id: UInt32 { scalar.value }
    public let scalar: Unicode.Scalar
    public let rule: Rule
    public let count: Int
    public let willProcess: Bool

    public var code: String { Cleaner.codeLabel(scalar) }
    public var name: String { scalar.properties.name ?? code }
}

public enum Cleaner {
    // MARK: 分類

    static let zeroWidth: Set<UInt32> = [
        0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0x00AD, 0x034F, 0x180E,
        0x2061, 0x2062, 0x2063, 0x2064, 0x115F, 0x1160, 0x3164, 0xFFA0,
    ]
    static let lineSeparators: Set<UInt32> = [0x2028, 0x2029, 0x0085]
    static let quotes: [UInt32: Unicode.Scalar] = [0x201C: "\"", 0x201D: "\"", 0x2018: "'", 0x2019: "'"]
    static let dashes: [UInt32: Unicode.Scalar] = [0x2014: "-", 0x2013: "-"]

    /// 1文字ずつ判定するルールの分類。対象外は nil
    public static func classify(_ v: UInt32) -> Rule? {
        if zeroWidth.contains(v) { return .zeroWidth }
        if v == 0x200E || v == 0x200F || v == 0x061C { return .bidi }
        if (0x202A...0x202E).contains(v) || (0x2066...0x2069).contains(v) { return .bidi }
        if (0xE0000...0xE007F).contains(v) { return .tag }
        if lineSeparators.contains(v) { return .lineSeparator }
        if v == 0x0D { return .newline }
        if (v <= 0x1F && v != 0x09 && v != 0x0A) || (0x7F...0x9F).contains(v) { return .control }
        if v == 0x00A0 || v == 0x202F || v == 0x205F || (0x2000...0x200A).contains(v) { return .specialSpace }
        if v == 0x3000 { return .ideographicSpace }
        if quotes[v] != nil { return .curlyQuotes }
        if dashes[v] != nil { return .dashes }
        return nil
    }

    public static func codeLabel(_ s: Unicode.Scalar) -> String {
        let hex = String(s.value, radix: 16, uppercase: true)
        return "U+" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
    }

    /// 絵文字かどうか（Emoji かつ U+00FF より後、または肌色修飾子）
    static func isEmoji(_ s: Unicode.Scalar?) -> Bool {
        guard let s else { return false }
        let p = s.properties
        return (p.isEmoji && s.value > 0xFF) || p.isEmojiModifier
    }

    /// 残す位置：絵文字の間の ZWJ（直前が VS16 ならその前を見る）と、🏴 に続くタグ文字
    static func protectedIndices(_ s: [Unicode.Scalar]) -> Set<Int> {
        var result = Set<Int>()
        var inFlag = false
        for i in s.indices {
            let v = s[i].value
            if v == 0x200D {
                let prevIndex = (i >= 1 && s[i - 1].value == 0xFE0F) ? i - 2 : i - 1
                let prev: Unicode.Scalar? = prevIndex >= 0 ? s[prevIndex] : nil
                let next: Unicode.Scalar? = i + 1 < s.count ? s[i + 1] : nil
                if isEmoji(prev) && isEmoji(next) { result.insert(i) }
            }
            if (0xE0020...0xE007F).contains(v) && (inFlag || (i >= 1 && s[i - 1].value == 0x1F3F4)) {
                result.insert(i)
                inFlag = v != 0xE007F
            } else {
                inFlag = false
            }
        }
        return result
    }

    // MARK: 処理

    /// 対象の文字を探す（オン・オフに関係なくすべて返す）
    public static func scan(_ text: String) -> [Finding] {
        let scalars = Array(text.unicodeScalars)
        let prot = protectedIndices(scalars)
        var findings: [Finding] = []
        for (i, s) in scalars.enumerated() {
            if let rule = classify(s.value) {
                findings.append(Finding(index: i, scalar: s, rule: rule, isProtected: prot.contains(i)))
            }
        }
        return findings
    }

    public static func clean(_ text: String, options: CleanOptions = .default) -> CleanResult {
        let scalars = Array(text.unicodeScalars)
        let findings = scan(text)
        var byIndex: [Int: Finding] = [:]
        for f in findings { byIndex[f.index] = f }

        var out: [Unicode.Scalar] = []
        out.reserveCapacity(scalars.count)
        var removed = 0
        var replaced = 0
        var breakdown: [Rule: Int] = [:]

        for (i, s) in scalars.enumerated() {
            guard let f = byIndex[i], !f.isProtected, options[f.rule] else {
                out.append(s)
                continue
            }
            switch f.rule {
            case .newline:
                // CRLF → LF（CR を落とす）/ 単独の CR → LF。数には入れない
                if !(i + 1 < scalars.count && scalars[i + 1] == "\n") { out.append("\n") }
            case .lineSeparator:
                out.append("\n"); replaced += 1; breakdown[f.rule, default: 0] += 1
            case .specialSpace, .ideographicSpace:
                out.append(" "); replaced += 1; breakdown[f.rule, default: 0] += 1
            case .curlyQuotes:
                out.append(quotes[s.value]!); replaced += 1; breakdown[f.rule, default: 0] += 1
            case .dashes:
                out.append(dashes[s.value]!); replaced += 1; breakdown[f.rule, default: 0] += 1
            default:
                removed += 1; breakdown[f.rule, default: 0] += 1
            }
        }

        if options[.trailingWhitespace] { out = stripTrailingWhitespace(out) }
        if options[.collapseBlankLines] { out = collapseBlankLines(out) }
        if options[.trim] { out = trimEdges(out) }

        var view = String.UnicodeScalarView()
        view.append(contentsOf: out)
        let result = String(view)
        return CleanResult(
            text: result,
            removedCount: removed,
            replacedCount: replaced,
            breakdown: breakdown,
            findings: findings,
            changed: !result.unicodeScalars.elementsEqual(text.unicodeScalars)
        )
    }

    /// 内訳（文字ごとの件数）。残す絵文字の結合や、見える文字でオフのルールは除く
    public static func summarize(_ findings: [Finding], options: CleanOptions = .default) -> [SummaryItem] {
        var counts: [UInt32: (Unicode.Scalar, Rule, Int)] = [:]
        var order: [UInt32] = []
        for f in findings where !f.isProtected && (options[f.rule] || f.rule.isInvisibleKind) {
            if let e = counts[f.scalar.value] {
                counts[f.scalar.value] = (e.0, e.1, e.2 + 1)
            } else {
                counts[f.scalar.value] = (f.scalar, f.rule, 1)
                order.append(f.scalar.value)
            }
        }
        return order
            .compactMap { counts[$0] }
            .map { SummaryItem(scalar: $0.0, rule: $0.1, count: $0.2, willProcess: options[$0.1]) }
            .sorted { $0.count > $1.count }
    }

    // MARK: 文章全体のルール

    private static func isSpaceOrTab(_ s: Unicode.Scalar) -> Bool { s == " " || s == "\t" }

    /// 各行の末尾のスペース・タブを消す（CRLF の場合は CR の前を見る）
    static func stripTrailingWhitespace(_ s: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var out: [Unicode.Scalar] = []
        out.reserveCapacity(s.count)
        var pending: [Unicode.Scalar] = []
        for (i, c) in s.enumerated() {
            if isSpaceOrTab(c) {
                pending.append(c)
            } else if c == "\n" {
                pending.removeAll(); out.append(c)
            } else if c == "\r" && (i + 1 == s.count || s[i + 1] == "\n") {
                pending.removeAll(); out.append(c)
            } else {
                out.append(contentsOf: pending); pending.removeAll(); out.append(c)
            }
        }
        return out
    }

    /// 改行が4つ以上続く（空行が3行以上）ところを空行1行にまとめる
    static func collapseBlankLines(_ s: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var out: [Unicode.Scalar] = []
        out.reserveCapacity(s.count)
        var run = 0
        let lf: Unicode.Scalar = "\n"
        func flush() {
            out.append(contentsOf: Array(repeating: lf, count: run >= 4 ? 2 : run))
            run = 0
        }
        for c in s {
            if c == "\n" { run += 1 } else { flush(); out.append(c) }
        }
        flush()
        return out
    }

    /// 文章全体の前後の半角スペース・タブ・改行を消す（全角スペースは残す）
    static func trimEdges(_ s: [Unicode.Scalar]) -> [Unicode.Scalar] {
        func isEdge(_ c: Unicode.Scalar) -> Bool { c == " " || c == "\t" || c == "\n" || c == "\r" }
        guard let first = s.firstIndex(where: { !isEdge($0) }),
              let last = s.lastIndex(where: { !isEdge($0) }) else { return [] }
        return Array(s[first...last])
    }
}
