import Foundation

/// 文字処理ルール（仕様書「文字処理ルール」の各行に対応）
public enum Rule: String, CaseIterable, Codable, Sendable, Identifiable {
    case zeroWidth
    case bidi
    case tag
    case control
    case specialSpace
    case ideographicSpace
    case lineSeparator
    case newline
    case trailingWhitespace
    case trim
    case collapseBlankLines
    case curlyQuotes
    case dashes

    public var id: String { rawValue }

    /// 既定でオンかどうか
    public var defaultOn: Bool {
        switch self {
        case .ideographicSpace, .collapseBlankLines, .curlyQuotes, .dashes:
            return false
        default:
            return true
        }
    }

    /// 見えない（または見分けにくい）文字を扱うルールか。ウィンドウでの表示に使う
    public var isInvisibleKind: Bool {
        switch self {
        case .zeroWidth, .bidi, .tag, .control, .specialSpace, .ideographicSpace, .lineSeparator, .newline:
            return true
        default:
            return false
        }
    }

    public var title: String {
        switch self {
        case .zeroWidth: return "ゼロ幅文字"
        case .bidi: return "書字方向の制御文字"
        case .tag: return "タグ文字"
        case .control: return "その他の制御文字"
        case .specialSpace: return "特殊な空白"
        case .ideographicSpace: return "全角スペース"
        case .lineSeparator: return "行区切り文字"
        case .newline: return "改行コード"
        case .trailingWhitespace: return "行末の空白"
        case .trim: return "先頭と末尾の空白"
        case .collapseBlankLines: return "続きすぎた空行"
        case .curlyQuotes: return "カーリークォート"
        case .dashes: return "ダッシュ"
        }
    }

    public var target: String {
        switch self {
        case .zeroWidth: return "U+200B〜200D、U+2060、U+FEFF、U+00AD など"
        case .bidi: return "U+200E、U+200F、U+202A〜202E、U+2066〜2069"
        case .tag: return "U+E0000〜E007F"
        case .control: return "改行・タブ以外の C0/C1 制御文字"
        case .specialSpace: return "U+00A0、U+2000〜200A、U+202F、U+205F"
        case .ideographicSpace: return "U+3000"
        case .lineSeparator: return "U+2028、U+2029、U+0085"
        case .newline: return "CRLF、CR"
        case .trailingWhitespace: return "各行の末尾のスペース・タブ"
        case .trim: return "文章全体の前後の半角の空白と改行（全角スペースの字下げは残す）"
        case .collapseBlankLines: return "3行以上の空行"
        case .curlyQuotes: return "“ ” ‘ ’"
        case .dashes: return "— –"
        }
    }

    public var action: String {
        switch self {
        case .zeroWidth, .bidi, .tag, .control, .trailingWhitespace, .trim: return "削除"
        case .specialSpace, .ideographicSpace: return "半角スペースに置換"
        case .lineSeparator: return "改行に置換"
        case .newline: return "LF にそろえる"
        case .collapseBlankLines: return "1行にまとめる"
        case .curlyQuotes: return "まっすぐな \" ' に置換"
        case .dashes: return "ハイフンに置換"
        }
    }
}

/// ルールごとのオン・オフ。保存していないルールは既定値を使う（ルールを足しても古い設定が壊れない）
public struct CleanOptions: Codable, Equatable, Sendable {
    private var values: [String: Bool]

    public init(_ overrides: [Rule: Bool] = [:]) {
        values = [:]
        for (rule, on) in overrides { values[rule.rawValue] = on }
    }

    public static let `default` = CleanOptions()

    public subscript(rule: Rule) -> Bool {
        get { values[rule.rawValue] ?? rule.defaultOn }
        set { values[rule.rawValue] = newValue }
    }

    /// 実際のオン・オフで比べる（既定値と同じ値を明示的に保存していても等しい）
    public static func == (lhs: CleanOptions, rhs: CleanOptions) -> Bool {
        Rule.allCases.allSatisfy { lhs[$0] == rhs[$0] }
    }

    /// テストケース（cases.json）の "options" から作る
    public init(overrides: [String: Bool]) {
        values = overrides.filter { Rule(rawValue: $0.key) != nil }
    }
}
