import AppKit
import SwiftUI
import CleanBunshoCore

/// クリーナーウィンドウ（ブラウザ版と同じ構成：左に入力、右に結果、内訳、見えない文字の表示）
struct CleanerView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var input = ""
    @State private var copied = false

    var body: some View {
        let result = Cleaner.clean(input, options: settings.options)
        let summary = Cleaner.summarize(result.findings, options: settings.options)

        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Pane(title: "入力") {
                    Button("貼り付け") { pasteFromClipboard() }
                    Button("クリア") { input = "" }
                        .disabled(input.isEmpty)
                } content: {
                    TextEditor(text: $input)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                } footer: {
                    Text("\(input.count) 文字")
                }

                Pane(title: "結果") {
                    Button(copied ? "コピーしました" : "コピー") { copyResult(result.text) }
                        .buttonStyle(.borderedProminent)
                        .disabled(result.text.isEmpty)
                } content: {
                    ScrollView {
                        Text(result.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(6)
                    }
                } footer: {
                    Text(resultFooter(result))
                }
            }
            .frame(minHeight: 260)

            HStack(alignment: .top, spacing: 12) {
                Pane(title: "見えない文字の表示") {
                    EmptyView()
                } content: {
                    ScrollView {
                        Text(Self.markedText(input, findings: result.findings, options: settings.options))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(6)
                    }
                } footer: {
                    Text("色の付いた印が見えない文字です（灰色はオフのルール）")
                }

                Pane(title: "内訳") {
                    Text("\(summary.reduce(0) { $0 + $1.count }) 件")
                        .foregroundStyle(summary.isEmpty ? Color.secondary : Color.orange)
                } content: {
                    if summary.isEmpty {
                        Text(input.isEmpty ? "文章を入力してください" : "見えない文字は見つかりませんでした")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Table(summary) {
                            TableColumn("コード", value: \.code)
                                .width(min: 70, ideal: 80)
                            TableColumn("名前", value: \.name)
                            TableColumn("種類") { Text($0.rule.title) }
                            TableColumn("件数") { Text("\($0.count)").monospacedDigit() }
                                .width(min: 36, ideal: 44)
                            TableColumn("処理") { item in
                                Text(item.willProcess ? item.rule.action : "残す")
                                    .foregroundStyle(item.willProcess ? Color.primary : Color.secondary)
                            }
                        }
                    }
                } footer: {
                    EmptyView()
                }
            }
            .frame(minHeight: 200)
        }
        .padding(14)
        .frame(minWidth: 760, minHeight: 520)
    }

    private func resultFooter(_ r: CleanResult) -> String {
        var s = "\(r.text.count) 文字"
        if r.removedCount > 0 { s += "・\(r.removedCount)個を削除" }
        if r.replacedCount > 0 { s += "・\(r.replacedCount)個を置換" }
        return s
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) { input = s }
    }

    private func copyResult(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    /// 見えない文字を「200B」のような印に置き換えた表示用の文字列
    static func markedText(_ input: String, findings: [Finding], options: CleanOptions) -> AttributedString {
        var marks: [Int: Finding] = [:]
        for f in findings where !f.isProtected && (options[f.rule] || f.rule.isInvisibleKind) {
            marks[f.index] = f
        }
        var out = AttributedString()
        var buffer = String.UnicodeScalarView()
        func flush() {
            guard !buffer.isEmpty else { return }
            out += AttributedString(String(buffer))
            buffer = String.UnicodeScalarView()
        }
        for (i, scalar) in input.unicodeScalars.enumerated() {
            guard let f = marks[i] else {
                buffer.append(scalar)
                continue
            }
            flush()
            let active = options[f.rule]
            var mark = AttributedString(" " + String(f.code.dropFirst(2)) + " ")
            mark.font = Font.system(size: 10, weight: .bold, design: .monospaced)
            mark.foregroundColor = active ? Color.orange : Color.secondary
            mark.backgroundColor = (active ? Color.orange : Color.gray).opacity(0.18)
            out += mark
            if f.rule == .lineSeparator { out += AttributedString("\n") }
        }
        flush()
        return out
    }
}

/// 見出し・中身・下の注記を持つ枠
struct Pane<Actions: View, Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder var actions: Actions
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                actions
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            footer
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
