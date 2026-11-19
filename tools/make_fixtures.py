"""cases.json を生成する補助スクリプト。

見えない文字をそのまま JSON に書くと目で確認できないため、ここで \\uXXXX 形式に
エスケープして書き出す。テストケースを足すときは CASES に追記して実行する:

    python3 tools/make_fixtures.py
    node tools/check-fixtures.mjs
"""
import json
import pathlib
import unicodedata

OUT = pathlib.Path(__file__).resolve().parent.parent / "Tests/CleanBunshoCoreTests/Fixtures/cases.json"

FAMILY = "👨‍👩‍👧"
HEART_FIRE = "❤️‍🔥"
CODER = "👩🏻‍💻"
SCOTLAND = "🏴\U000E0067\U000E0062\U000E0073\U000E0063\U000E0074\U000E007F"

# (名前, 入力, 期待する結果, 削除数, 置換数, オプションの上書き)
CASES = [
    ("変更なし", "こんにちは、世界。\nHello!", "こんにちは、世界。\nHello!", 0, 0, {}),
    ("ゼロ幅スペース", "AIが​生成した​文章", "AIが生成した文章", 2, 0, {}),
    ("ZWNJ・WJ・BOM・ソフトハイフン", "﻿テ‌キ⁠ス­ト", "テキスト", 4, 0, {}),
    ("不可視の演算子・CGJ・モンゴル母音区切り", "a⁢b͏c᠎d", "abcd", 3, 0, {}),
    ("ハングルのフィラー", "xㅤyﾠz", "xyz", 2, 0, {}),
    ("書字方向の制御文字", "abc‮def‬‎ghi⁦j⁩‏", "abcdefghij", 6, 0, {}),
    ("タグ文字", "hi\U000E0041\U000E0042\U000E007F!", "hi!", 3, 0, {}),
    ("旗の絵文字のタグ文字は残す", "Go " + SCOTLAND + "!", "Go " + SCOTLAND + "!", 0, 0, {}),
    ("C0/C1 制御文字（タブ・改行は残す）", "a\u0000b\u0007c\td\u001be\u0080f\u009fg\nh", "abc\tdefg\nh", 5, 0, {}),
    ("DEL", "a\u007fb", "ab", 1, 0, {}),
    ("特殊な空白", "a b c d e f", "a b c d e f", 0, 5, {}),
    ("全角スペースは既定で残す", "日本語　テキスト", "日本語　テキスト", 0, 0, {}),
    ("全角スペースをオンにすると置換", "日本語　テキスト", "日本語 テキスト", 0, 1, {"ideographicSpace": True}),
    ("行区切り文字は改行に", "一行目 二行目 三行目\u0085四行目", "一行目\n二行目\n三行目\n四行目", 0, 3, {}),
    ("CRLF と CR を LF に（数えない）", "a\r\nb\rc\n", "a\nb\nc", 0, 0, {}),
    ("改行コードをオフ", "a\r\nb", "a\r\nb", 0, 0, {"newline": False}),
    ("行末の空白", "a  \nb\t\nc \t ", "a\nb\nc", 0, 0, {}),
    ("先頭と末尾の空白・改行", "\n\n  本文です。  \n\n", "本文です。", 0, 0, {}),
    ("全角スペースの字下げは残す", "\n　本文です。\n", "　本文です。", 0, 0, {}),
    ("先頭と末尾をオフ", "  a  ", "  a", 0, 0, {"trim": False}),
    ("行末と先頭末尾の両方をオフ", "  a  ", "  a  ", 0, 0, {"trim": False, "trailingWhitespace": False}),
    ("続きすぎた空行は既定で残す", "a\n\n\n\nb", "a\n\n\n\nb", 0, 0, {}),
    ("続きすぎた空行をまとめる", "a\n\n\n\nb\n\n\nc\n\n\n\n\n\nd", "a\n\nb\n\n\nc\n\nd", 0, 0, {"collapseBlankLines": True}),
    ("空白だけの行も空行として扱う", "a\n  \n \t\n\t\nb", "a\n\nb", 0, 0, {"collapseBlankLines": True}),
    ("カーリークォートは既定で残す", "“Hi” ‘a’", "“Hi” ‘a’", 0, 0, {}),
    ("カーリークォートを置換", "“Hi” it’s ‘a’", "\"Hi\" it's 'a'", 0, 5, {"curlyQuotes": True}),
    ("ダッシュを置換", "A—B–C", "A-B-C", 0, 2, {"dashes": True}),
    ("絵文字の ZWJ は残す", FAMILY + HEART_FIRE + CODER, FAMILY + HEART_FIRE + CODER, 0, 0, {}),
    ("文字の間の ZWJ は消す", "テ‍キスト😀‍a", "テキスト😀a", 2, 0, {}),
    ("異体字セレクタは触らない", "葛\U000E0100 ☺️", "葛\U000E0100 ☺️", 0, 0, {}),
    ("ルールをオフにすると残る", "a​b", "a​b", 0, 0, {"zeroWidth": False}),
    (
        "まとめて",
        "﻿  AIの​回答です 。\r\n‮結論‬：OK  \r\n",
        "AIの回答です 。\n結論：OK",
        4, 1, {},
    ),
]


def escape(s: str) -> str:
    """見えない文字・空白類だけを \\uXXXX にする（日本語や絵文字はそのまま）"""
    out = []
    for ch in s:
        cp = ord(ch)
        cat = unicodedata.category(ch)
        visible = cat[0] not in "CZ" or ch == " "
        if cp in (0x3000, 0x034F, 0x3164, 0xFFA0, 0x115F, 0x1160) or cp > 0xE0000 or (0xFE00 <= cp <= 0xFE0F):
            visible = False
        if visible:
            out.append(json.dumps(ch, ensure_ascii=False)[1:-1])
        elif cp > 0xFFFF:
            v = cp - 0x10000
            out.append("\\u%04x\\u%04x" % (0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF)))
        else:
            out.append(json.dumps(ch)[1:-1] if ch in "\n\t\r" else "\\u%04x" % cp)
    return '"' + "".join(out) + '"'


def main():
    lines = ["{", '  "version": 1,', '  "cases": [']
    for n, (name, inp, exp, rem, rep, opts) in enumerate(CASES):
        item = (
            "    {\n"
            f'      "name": {json.dumps(name, ensure_ascii=False)},\n'
            f'      "input": {escape(inp)},\n'
            f'      "expected": {escape(exp)},\n'
            f'      "removed": {rem},\n'
            f'      "replaced": {rep},\n'
            f'      "options": {json.dumps(opts)}\n'
            "    }"
        )
        lines.append(item + ("," if n < len(CASES) - 1 else ""))
    lines += ["  ]", "}", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    # 書き出した JSON が元のデータと一致するか確認
    data = json.loads(OUT.read_text(encoding="utf-8"))
    for c, (name, inp, exp, *_rest) in zip(data["cases"], CASES):
        assert c["input"] == inp and c["expected"] == exp, name
    print(f"{len(CASES)} cases -> {OUT}")


if __name__ == "__main__":
    main()
